# ============================================
# Local values
# ============================================
locals {
  config     = jsondecode(file("../../config/ecs-fargate-service/service.json"))
  clusters   = jsondecode(file("../../config/ecs-fargate-service/clusters.json"))
  namespaces = jsondecode(file("../../config/ecs-fargate-service/namespaces.json"))
  dynatrace  = jsondecode(file("../../config/ecs-fargate-service/dynatrace.json"))
  common     = jsondecode(file("../../config/common.json"))

  cluster  = local.clusters[local.config["cluster_to_use"]]
  all_tags = local.common["tags"]

  # Service Discovery (Cloud Map)
  sd_enabled        = local.config["srv_discovery"]
  sd_namespace_name = try(local.namespaces[local.config["cluster_to_use"]].namespace_name, null)
}

# ============================================
# Data Sources - Existing ALB
# ============================================
data "aws_lb" "existing" {
  name = local.cluster["alb_name"]
}

data "aws_lb_listener" "existing" {
  load_balancer_arn = data.aws_lb.existing.arn
  port              = local.cluster["alb_listener_port"]
}

# ============================================
# Module: ECR
# ============================================
module "ecr" {
  source = "../../modules/ecr"

  service_name           = local.config["service_name"]
  image_tag_mutability   = "MUTABLE"
  scan_on_push           = true
  lifecycle_policy_count = 10
  tags                   = local.all_tags
}

# ============================================
# Module: CloudWatch
# ============================================
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  service_name            = local.config["service_name"]
  retention_in_days       = var.log_retention_days
  log_group_name_override = "/ecs/${local.config["service_name"]}"
  enable_log_group_tags   = true
  tags                    = local.all_tags
}

# ============================================
# Module: ALB
# ============================================
module "alb" {
  source = "../../modules/alb"

  service_name           = local.config["service_name"]
  vpc_id                 = local.cluster["vpc_id"]
  alb_listener_arn       = data.aws_lb_listener.existing.arn
  container_port         = local.config["container_port"]
  health_check_path      = local.config["tg_health_check_path"]
  health_check_interval  = local.config["tg_health_check_interval"]
  health_check_timeout   = local.config["tg_health_check_timeout"]
  healthy_threshold      = local.config["tg_healthy_threshold"]
  unhealthy_threshold    = local.config["tg_unhealthy_threshold"]
  path_pattern           = local.config["alb_path_pattern"]
  listener_rule_priority = try(local.config["alb_priority"], null)

  tags = local.all_tags
}

# ============================================
# Module: Service Discovery (Cloud Map) - only when srv_discovery = true
# ============================================
module "service_discovery" {
  source = "../../modules/service-discovery"
  count  = local.sd_enabled ? 1 : 0

  service_name   = local.config["service_name"]
  namespace_name = local.sd_namespace_name
  cluster_key    = local.config["cluster_to_use"]
  tags           = local.all_tags
}

# ============================================
# Module: ECS Service (Task Definition + ECS Service)
# ============================================
module "ecs_service" {
  source = "../../modules/ecs-fargate-service"

  service_name                     = local.config["service_name"]
  cluster_name                     = local.cluster["cluster_name"]
  container_port                   = local.config["container_port"]
  task_cpu                         = local.config["td_task_cpu"]
  task_memory                      = local.config["td_task_ram"]
  main_cpu                         = local.config["td_main_cpu"]
  main_memory                      = local.config["td_main_ram"]
  dynatrace_cpu                    = local.config["td_dynatrace_cpu"]
  dynatrace_memory                 = local.config["td_dynatrace_ram"]
  dynatrace_oneagent_options_param = local.config["td_dynatrace_oneagent_options_param"]
  dynatrace                        = local.dynatrace
  ecr_repository_url               = module.ecr.repository_url
  image_tag                        = local.config["ecr_image_tag"]
  subnet_ids                       = local.cluster["private_subnet_ids"]
  security_group_ids               = [local.cluster["cluster_security_group_id"]]
  target_group_arn                 = module.alb.target_group_arn
  log_group_name                   = module.cloudwatch.log_group_name
  aws_region                       = var.aws_region
  main_secrets                     = local.config["td_main_secrets"]
  service_registry_arn             = local.sd_enabled ? module.service_discovery[0].arn : null
  tags                             = local.all_tags

  depends_on = [module.ecr, module.cloudwatch, module.alb]
}
