output "parameter_arns" {
  description = "ARNs of the created parameters"
  value       = module.parameter_store.parameter_arns
}

output "parameter_names" {
  description = "Names of the created parameters"
  value       = module.parameter_store.parameter_names
}
