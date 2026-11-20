data "aws_ecs_cluster" "this" {
  cluster_name = var.cluster_name
}

# Current account, used to build ARNs dynamically
data "aws_caller_identity" "current" {}

locals {
  ecs_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"

  # SSM ARN prefix (agnostic: uses the current account + region)
  ssm_arn_prefix = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter"

  # OneAgent runtime settings: the agent reads them inside the service process, so they go to the main container
  oneagent_runtime_secret_names = ["DT_LOGLEVELCON", "DT_NETWORK_ZONE"]

  # Main container secrets (valueFrom in service.json is the SSM parameter name; the module builds the full ARN)
  main_container_secrets = concat(
    [for s in var.main_secrets : { name = s.name, valueFrom = "${local.ssm_arn_prefix}${s.valueFrom}" }],
    [
      { name = "DT_LOGLEVELCON", valueFrom = "${local.ssm_arn_prefix}${var.dynatrace.ssm_log_level_con}" },
      { name = "DT_NETWORK_ZONE", valueFrom = "${local.ssm_arn_prefix}${var.dynatrace.ssm_network_zone}" },
    ]
  )

  # Dynatrace installer (sidecar): only what the download needs. Shared settings come from var.dynatrace
  # (dynatrace.json); cpu/ram and DT_ONEAGENT_OPTIONS come from the service config (front/back differ).
  dynatrace_container_secrets = [
    { name = "DT_API_URL", valueFrom = "${local.ssm_arn_prefix}${var.dynatrace.ssm_api_url}" },
    { name = "DT_ONEAGENT_OPTIONS", valueFrom = "${local.ssm_arn_prefix}${var.dynatrace_oneagent_options_param}" },
    { name = "DT_PAAS_TOKEN", valueFrom = "${local.ssm_arn_prefix}${var.dynatrace.ssm_paas_token}" },
  ]

  # TLS verification stays on unless the Dynatrace endpoint (e.g. an ActiveGate) uses a self-signed certificate
  dynatrace_wget_flags = var.dynatrace.skip_tls_verify ? "--no-check-certificate " : ""
}

# ==========================================
# TASK DEFINITION (2 containers: service + Dynatrace)
# ==========================================
resource "aws_ecs_task_definition" "this" {
  family                   = "td-${var.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = local.ecs_role_arn
  task_role_arn            = local.ecs_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name = "tempvolume"
  }

  volume {
    name = "oneagent"
  }

  # Scratch space for the installer download (the root filesystem is read-only)
  volume {
    name = "oneagent-tmp"
  }

  container_definitions = jsonencode([
    # ---- Main container (service) ----
    {
      name      = "container-${var.service_name}"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      cpu       = var.main_cpu
      memory    = var.main_memory
      essential = true

      readonlyRootFilesystem = true

      portMappings = [{
        name          = "container-${var.service_name}-${var.container_port}-tcp"
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      mountPoints = [
        {
          sourceVolume  = "tempvolume"
          containerPath = "/shared-volume"
          readOnly      = false
        },
        {
          sourceVolume  = "oneagent"
          containerPath = "/opt/dynatrace/oneagent"
          readOnly      = false
        }
      ]

      environment = []
      secrets     = local.main_container_secrets

      dependsOn = [{
        containerName = "install-oneagent"
        condition     = "COMPLETE"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    },
    # ---- Dynatrace container (install-oneagent): downloads OneAgent into the shared volume and exits ----
    {
      name      = "install-oneagent"
      image     = var.dynatrace.installer_image
      cpu       = var.dynatrace_cpu
      memory    = var.dynatrace_memory
      essential = false

      readonlyRootFilesystem = true

      entryPoint = ["/bin/sh", "-c"]
      command    = ["mkdir -p /opt/temp/ && ARCHIVE=/opt/temp/agent.zip && wget ${local.dynatrace_wget_flags}-O $ARCHIVE \"$DT_API_URL/v1/deployment/installer/agent/unix/paas/latest?arch=$ARCH&Api-Token=$DT_PAAS_TOKEN&$DT_ONEAGENT_OPTIONS\" && unzip -o -d /opt/dynatrace/oneagent $ARCHIVE && rm -f $ARCHIVE"]

      portMappings = []
      environment = [
        { name = "ARCH", value = var.dynatrace.arch }
      ]

      mountPoints = [
        {
          sourceVolume  = "oneagent"
          containerPath = "/opt/dynatrace/oneagent"
          readOnly      = false
        },
        {
          sourceVolume  = "oneagent-tmp"
          containerPath = "/opt/temp"
          readOnly      = false
        }
      ]

      secrets = local.dynatrace_container_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.dynatrace.log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.main_cpu + var.dynatrace_cpu <= var.task_cpu
      error_message = "main_cpu (${var.main_cpu}) + dynatrace_cpu (${var.dynatrace_cpu}) exceeds task_cpu (${var.task_cpu})."
    }

    precondition {
      condition     = length(setintersection([for s in var.main_secrets : s.name], local.oneagent_runtime_secret_names)) == 0
      error_message = "main_secrets must not define ${join(" or ", local.oneagent_runtime_secret_names)}: the module adds them from var.dynatrace."
    }
  }
}

# ==========================================
# ECS SERVICE
# ==========================================
resource "aws_ecs_service" "this" {
  name            = "srv-${var.service_name}"
  cluster         = data.aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  force_new_deployment = true

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "container-${var.service_name}"
    container_port   = var.container_port
  }

  # Service Discovery (Cloud Map): only when a registry ARN is provided
  dynamic "service_registries" {
    for_each = var.service_registry_arn == null ? [] : [1]
    content {
      registry_arn   = var.service_registry_arn
      container_name = "container-${var.service_name}"
      container_port = var.container_port
    }
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  tags = var.tags

  lifecycle {
    ignore_changes = [desired_count]
  }
}
