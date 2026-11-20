# ============================================
# Local values
# ============================================
locals {
  parameters = jsondecode(file("../../config/parameter-store/parameters.json"))
  common     = jsondecode(file("../../config/common.json"))

  all_tags = local.common["tags"]
}

# ============================================
# Module: Parameter Store
# ============================================
module "parameter_store" {
  source = "../../modules/parameter-store"

  parameters = local.parameters
  tags       = local.all_tags
}
