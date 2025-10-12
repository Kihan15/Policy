terraform {
  required_version = ">= 1.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.12"
    }
  }
}

provider "azurerm" {
  features {}
}

# ------------------------------------------------------------
# 1. Creation of Individual Policy Definitions
# ------------------------------------------------------------

# Find and read the file data into local Variables..
locals {
  policy_files = fileset("./policy/tag", "*.json")
  raw_data     = [for f in local.policy_files : jsondecode(file("./policy/tag/${f}"))]
}

/*
 'for' expression is used to convert the Tuple (from local.json_data), to an Object type.
 In depth explanation of 'for' expression can be found in the Readme
*/


module "custom_policy" {
  for_each = { for f in local.raw_data : f.name => f }
  source   = "./modules/policy_definition"

  policy_name  = each.key
  policy_mode  = each.value.properties.mode
  display_name = each.value.properties.displayName
  metadata     = jsonencode("${each.value.properties.metadata}")   #format("<<METADATA \n %s \n METADATA", each.value.properties.metadata)
  parameters   = jsonencode("${each.value.properties.parameters}") #format("<<PARAMETERS \n %s \n PARAMETERS", each.value.properties.parameters)
  policy_rule  = jsonencode("${each.value.properties.policyRule}") #format("<<POLICYRULE \n %s \n POLICYRULE", each.value.properties.policyRule)
  #management_group = var.management_group --- IGNORE --}
}



# ------------------------------------------------------------
# 2. Creation of initiative from Definitions.
# ------------------------------------------------------------

resource "azurerm_policy_set_definition" "initiative_mandatory_tags" {
  name         = "initiative-mandatory-tags-subs-rgs"
  display_name = "Mandatory Tags (Subscriptions & Resource Groups)"
  policy_type  = "Custom"
  description  = "Requires presence of governance tags on subscriptions and resource groups."
  metadata     = jsonencode({ category = "Tags" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      metadata      = { displayName = "Effect for all included policies" }
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  })

  ######################################################
  # References (all inherit initiative-level effect)   #
  ######################################################

policy_definition_reference {
    reference_id         = "BusinessOwnerRequired"
    # This now works because the output is defined in the module:
    policy_definition_id = module.custom_policy["tag-businessowner-required"].policy_definition_id
    #parameter_values    = jsonencode({ effect = { value = "[parameters('effect')]" } })
}

  policy_definition_reference {
    reference_id         = "EnvironmentRequiredAllowed"
    policy_definition_id = module.custom_policy["tag-environment-required-and-allowed-subs-rgs"].policy_definition_id
    #parameter_values     = jsonencode({ effect = { value = "[parameters('effect')]" } })
  }

  policy_definition_reference {
    reference_id         = "CompanyCodeRequired"
    policy_definition_id = module.custom_policy["tag-companycode-required"].policy_definition_id
    #parameter_values     = jsonencode({ effect = { value = "[parameters('effect')]" } })
  }
  policy_definition_reference {
    reference_id         = "ScmRequired"
    policy_definition_id = module.custom_policy["tag-scm-required"].policy_definition_id
    #parameter_values     = jsonencode({ effect = { value = "[parameters('effect')]" } })
  }

  policy_definition_reference {
    reference_id         = "DataClassificationRequiredAllowed"
    policy_definition_id = module.custom_policy["tag-dataclassification-required-and-allowed-subs-rgs"].policy_definition_id
    #parameter_values     = jsonencode({ effect = { value = "[parameters('effect')]" } })
  }

  policy_definition_reference {
    reference_id         = "BusinessCriticalityRequiredAllowed"
    policy_definition_id = module.custom_policy["tag-businesscriticality-required-and-allowed-subs-rgs"].policy_definition_id
    #parameter_values     = jsonencode({ effect = { value = "[parameters('effect')]" } })
  }

  policy_definition_reference {
    reference_id         = "CostCenterRequired"
    policy_definition_id = module.custom_policy["tag-costcenter-required"].policy_definition_id
    parameter_values     = jsonencode({ effect = { value = "[parameters('effect')]" } })
  }
  policy_definition_reference {
    reference_id         = "ProjectRequired"
    policy_definition_id = module.custom_policy["tag-project-required"].policy_definition_id
    #parameter_values     = jsonencode({ effect = { value = "[parameters('effect')]" } })
  }
  policy_definition_reference {
    reference_id         = "BusinessRequestRequired"
    policy_definition_id = module.custom_policy["tag-businessrequest-required"].policy_definition_id
    #parameter_values     = jsonencode({ effect = { value = "[parameters('effect')]" } })
  }
}




############################################################
# Assignment of Initiative tags to Subscription & resource groups)
############################################################
resource "azurerm_subscription_policy_assignment" "initiative_mandatory_tags_assignment" {
  name                 = "assignment-initiative-mandatory-tags-subs-rgs"
  display_name         = "Assignment: Mandatory Tags for Subscriptions & RGs"
  description          = "Audits subscriptions and resource groups to ensure mandatory tags exist."
  policy_definition_id = azurerm_policy_set_definition.initiative_mandatory_tags.id
  subscription_id      = "/subscriptions/${var.subscription_id}"
  enforce              = true

  # parameters = jsonencode({
  #   effect = { value = "Audit" }
  # })
}




# ------------------------------------------------------------
# 3. Demo Resources to test the policies  (can be ignored)      
# ------------------------------------------------------------

# create definitions by looping around all files found under the Monitoring category folder
module whitelist_regions {
  source                = "gettek/policy-as-code/azurerm//modules/definition"
  version = "2.10.1"
  policy_name           = "whitelist_regions"
  display_name          = "Allow resources only in whitelisted regions"
  policy_category       = "General"
  #management_group_id   = data.azurerm_management_group.org.id
}





############################################################################
# Deploy Azure Web app service with sample website from GitHub Repo
#############################################################################


# Resource Group
resource "azurerm_resource_group" "ccoe_rg" {
  name     = "ccoe-webapp-rg"
  location = "West Europe"
}

# App Service Plan
resource "azurerm_service_plan" "ccoe_plan" {
  name                = "ccoe-appservice-plan"
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name
  os_type             = "Linux"
  sku_name            = "B1" # Basic Tier
}

# Web App
resource "azurerm_app_service" "ccoe_webapp" {
  name                = "ccoe-webapp"
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name
  app_service_plan_id = azurerm_app_service_plan.ccoe_plan.id

  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  }
}

# GitHub Source Control (public repo).
resource "azurerm_app_service_source_control" "github_link" {
  app_id                 = azurerm_app_service.ccoe_webapp.id
  repo_url               = "https://github.com/Kihan15/Policy.git"
  branch                 = "main"
}
  