output "id" {
  description = "The Azure Resource ID of the created Policy Definition."
  value       = azurerm_policy_definition.def_policies.id
}
