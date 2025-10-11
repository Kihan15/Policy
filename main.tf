provider "azurerm" {
  features {}
  subscription_id = "d2c5b5b1-d8df-4dbd-ac14-d347e7ab31b0"
}

# Configuration du Management Group (Récupérez l'ID du groupe de gestion racine)
data "azurerm_management_group" "org" {
  name = "your_root_mg_id" # Remplacez par l'ID de votre groupe de gestion racine
}

# ------------------------------------------------------------
# 1. CRÉATION DES DÉFINITIONS DE POLITIQUES INDIVIDUELLES
# ------------------------------------------------------------
locals {
  # NOTE: Correction du chemin de fichier pour correspondre à fileset
  policy_files = fileset("./policy/tag", "*.json") [cite: 12] 
  raw_data     = [for f in local.policy_files : jsondecode(file("./policy/tag/${f}"))]
}


module "custom_policy" {
  for_each = { for f in local.raw_data : f.name => f }
  source   = "./modules/policy_definition"  # Utilise le nouveau module générique

  policy_name  = each.key
  policy_mode  = each.value.properties.mode
  display_name = each.value.properties.displayName
  metadata     = jsonencode(each.value.properties.metadata)
  parameters   = jsonencode(each.value.properties.parameters)
  policy_rule  = jsonencode(each.value.properties.policyRule)
}


# ------------------------------------------------------------
# 2. CRÉATION DE L'INITIATIVE À PARTIR DES DÉFINITIONS
# ------------------------------------------------------------
module "policy_initiative" {
  # Utilise le nouveau module générique
  source              = "./modules/policy_initiative" 

  initiative_name     = "initiative-mandatory-tags-custom"
  display_name        = "Mandatory Tagging Initiative (Custom)"
  description         = "Enforces all custom mandatory tagging policies."
  
  # Utilisation des variables pour la flexibilité (Tags pour l'instant)
  category            = "Tags"
  management_group_id = data.azurerm_management_group.org.id 

  # Construction dynamique du map {policy_name = policy_id} pour le module d'Initiative
  member_policy_ids = {
    for key, policy in module.custom_policy : key => policy.id
  }
  
  # Définition du paramètre commun exposé par l'Initiative
  initiative_parameters = {
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "The effect of the policy (Audit, Deny, or Disabled)."
      }
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  }
}