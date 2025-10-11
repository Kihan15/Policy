terraform {
  backend "azurerm" {
    resource_group_name  = "rg-automation-prod-d2c5b5b12"
    storage_account_name = "tfmstateprodd2c5b5b1"
    container_name       = "tfstate"
    key                  = "policy/terraform.tfstate"
  }
}
