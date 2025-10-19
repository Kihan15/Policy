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
resource "azurerm_resource_group" "ccoe_rg2" {
  name     = "ccoe-webapp-rg2"
  location = "West Europe"
}

# App Service Plan
resource "azurerm_service_plan" "ccoe_plan" {
  name                = "ccoe-appservice-plan2"
  location            = azurerm_resource_group.ccoe_rg2.location
  resource_group_name = azurerm_resource_group.ccoe_rg2.name
  os_type             = "Windows" 
  sku_name            = "B1"
}

# Web App
resource "azurerm_app_service" "ccoe_webapp" {
  name                = "ccoe-webapp2"
  location            = azurerm_resource_group.ccoe_rg2.location
  resource_group_name = azurerm_resource_group.ccoe_rg2.name
  app_service_plan_id = azurerm_service_plan.ccoe_plan.id

  app_settings = {
    
  }
}

  


  
############################################################################
# 1. NETWORKING: VNet, Subnets, and NSG
############################################################################

# Resource Group
resource "azurerm_resource_group" "ccoe_rg" {
  name     = "ccoe-hybrid-rg"
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "ccoe_vnet" {
  name                = "ccoe-vnet"
  address_space       = ["10.0.1.0/24"]
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name
}

# Subnet for the Windows 11 VM
resource "azurerm_subnet" "vm_subnet" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.ccoe_rg.name
  virtual_network_name = azurerm_virtual_network.ccoe_vnet.name
  address_prefixes     = ["10.0.1.0/28"]
}

# Subnet for Web App VNet Integration (requires delegation)
resource "azurerm_subnet" "webapp_integration_subnet" {
  name                 = "webapp-integration-subnet"
  resource_group_name  = azurerm_resource_group.ccoe_rg.name
  virtual_network_name = azurerm_virtual_network.ccoe_vnet.name
  address_prefixes     = ["10.0.1.16/28"]

  # Delegation is mandatory for Azure Web App VNet Integration
  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
    }
}
}

# Network Security Group (NSG) for the VM
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "vm-nsg"
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name

  # Allow RDP access from any source (for testing/initial access)
  security_rule {
    name                       = "RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }


# New Rule: Allow Outbound Web Traffic (HTTP/HTTPS) to Any Destination
  security_rule {
    name                       = "Allow_Egress_Web"
    priority                   = 110 # Set a higher priority than the RDP rule
    direction                  = "Outbound" # <--- Key: Specifies outgoing traffic
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"] # <--- Key: Web ports
    source_address_prefix      = "*"
    # The default Azure "AllowInternetOutbound" rule already allows egress to the Internet (*).
    # To specifically allow egress to 'any other subnet' within Azure and the Internet, 
    # using '*' for the destination is the appropriate setting here.
    destination_address_prefix = "*"
  }
}


############################################################################
# 2. WEB APP SERVICE with VNet Integration
############################################################################

# App Service Plan (B1 SKU supports VNet Integration)
resource "azurerm_service_plan" "ccoe_plan3" {
  name                = "ccoe-appservice-plan3"
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name
  os_type             = "Windows"
  sku_name            = "B1"
}

# Web App (using the integration subnet)
resource "azurerm_windows_web_app" "ccoe_webapp3" {
  name                = "ccoe-webapp3"
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name
  service_plan_id     = azurerm_service_plan.ccoe_plan3.id

  virtual_network_subnet_id = azurerm_subnet.webapp_integration_subnet.id

  site_config {
    # Assuming a simple web deployment (default settings)
  }
  
  # Deploy a sample site from a public GitHub repo


  app_settings = {
    
  }
}

############################################################################
# 3. PRIVATE LINK FOR STORAGE ACCOUNT
############################################################################

resource "azurerm_storage_account" "ccoe_storage" {
  name                     = "ccoepltfstorage${substr(replace(uuid(), "-", ""), 0, 8)}"
  resource_group_name      = azurerm_resource_group.ccoe_rg.name
  location                 = azurerm_resource_group.ccoe_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  public_network_access_enabled = false

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = []
    ip_rules                   = []
  }

  tags = {
    environment = "Production"
  }
}

# Private DNS Zone for Blob Storage
resource "azurerm_private_dns_zone" "storage_dns_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.ccoe_rg.name
}

# Link the Private DNS Zone to the Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "storage_dns_link" {
  name                  = "ccoe-vnet-link"
  resource_group_name   = azurerm_resource_group.ccoe_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.ccoe_vnet.id
}

# Private Endpoint (links the Storage Account to the VNet)
resource "azurerm_private_endpoint" "ccoe_storage_pe" {
  name                = "ccoe-storage-pe"
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name
  subnet_id           = azurerm_subnet.vm_subnet.id # Placing the PE in the VM subnet

  private_service_connection {
    name                           = "ccoe-storage-psc"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.ccoe_storage.id
    subresource_names              = ["blob"] # Use 'blob' for blob storage access
  }

  private_dns_zone_group {
    name                 = "private-dns-zone-group-blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_dns_zone.id]
  }
}

############################################################################
# 4. WINDOWS 11 VIRTUAL MACHINE
############################################################################

# Public IP for the VM's RDP access (optional, remove for pure private access)
resource "azurerm_public_ip" "vm_ip" {
  name                = "ccoe-vm-ip"
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface Card (NIC)
resource "azurerm_network_interface" "vm_nic" {
  name                = "ccoe-vm-nic"
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_ip.id
  }
}

# Attach NSG to the NIC
resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}


# Windows 11 Virtual Machine
resource "azurerm_windows_virtual_machine" "ccoe_vm" {
  name                = "ccoe-windows-vm"
  location            = azurerm_resource_group.ccoe_rg.location
  resource_group_name = azurerm_resource_group.ccoe_rg.name
  size                = "Standard_DS2_v2"
  network_interface_ids = [azurerm_network_interface.vm_nic.id]
  
  # Credentials for the VM
  admin_username = var.vm_admin_username
  admin_password = var.vm_admin_password
  
  # Use a Windows 11 image (must be licensed correctly, typically via AVD or specific marketplace offers)
  # This uses a standard Windows 11 Pro image for demonstration
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-avd" # Using a recent, common Windows 11 SKU
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}