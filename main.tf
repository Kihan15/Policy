terraform {
  required_version = ">= 1.1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "demo" {
  name     = "example-storage-test"
  location = "West Europe"
}

##  Demo of storage account
resource "azurerm_storage_account" "StorageAccountDemo" {
  name                     = "satestant000013"
  resource_group_name      = azurerm_resource_group.demo.name
  location                 = azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"

  tags = {
    video = "azure"
    channel = "CloudQuickLabs"
  }
}