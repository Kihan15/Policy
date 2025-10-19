variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}
variable "tenant_id" {
  type        = string
  description = "Target Azure subscription ID"
}

variable "location" {
  description = "The Azure region to deploy resources into."
  default     = "West Europe"
}

variable "vm_admin_username" {
  description = "Admin username for the Windows VM."
  default     = "vmadmin"
}

variable "vm_admin_password" {
  description = "Admin password for the Windows VM. MUST meet Azure complexity requirements (12+ chars, 3/4 complexity types)."
  default     = "P@ssw0rd123456" 
  sensitive   = true
}