output "policy_definition_id" {
  # The resource name defined in modules/policy_definition/main.tf is 'def_policies'
  value       = azurerm_policy_definition.def_policies.id 
  description = "The ID of the created Azure Policy Definition."
}