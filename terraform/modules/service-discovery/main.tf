# Consume an existing Cloud Map private DNS namespace
data "aws_service_discovery_dns_namespace" "this" {
  name = var.namespace_name
  type = "DNS_PRIVATE"

  lifecycle {
    precondition {
      condition     = var.namespace_name != null && var.namespace_name != ""
      error_message = "service_discovery=true but cluster '${var.cluster_key}' has no namespace in namespaces.json."
    }
  }
}

# Cloud Map service (nomenclature: sd-<service_name>)
resource "aws_service_discovery_service" "this" {
  name = "sd-${var.service_name}"

  dns_config {
    namespace_id   = data.aws_service_discovery_dns_namespace.this.id
    routing_policy = "MULTIVALUE"

    dns_records {
      type = "A"
      ttl  = 60
    }

    dns_records {
      type = "SRV"
      ttl  = 60
    }
  }

  health_check_custom_config {}

  tags = var.tags
}
