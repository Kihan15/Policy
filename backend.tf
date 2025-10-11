terraform {
  backend "azurerm" {
    resource_group_name  = "rg-automation-prod-2"
    storage_account_name = "tfmstateprodd2c5b5b1"
    container_name       = "tfstate"
    key                  = "policy/terraform.tfstate"
  }
}
