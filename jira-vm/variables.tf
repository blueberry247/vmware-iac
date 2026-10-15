# ============================================================
# vSphere Connection Variables
# ============================================================

variable "vsphere_user" {
  description = "vSphere username"
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "vSphere password"
  type        = string
  sensitive   = true
}

variable "vsphere_server" {
  description = "vCenter server"
  type        = string
}

# ============================================================
# Jira VM Request Variables
# ============================================================

variable "vm_name" {
  description = "VM name requested through Jira"
  type        = string
}

variable "vm_hostname" {
  description = "Guest OS hostname"
  type        = string
}

variable "vm_cpu" {
  description = "Number of virtual CPUs"
  type        = number
}

variable "vm_memory" {
  description = "Memory in MB"
  type        = number
}

variable "vm_network" {
  description = "vSphere network"
  type        = string
}
variable "vm_os" {
  description = "Operating system selected in Jira"
  type        = string
  default     = "Debian 13"

  validation {
    condition     = contains(["Debian 13", "Windows Server 2022"], var.vm_os)
    error_message = "Operating system must be Debian 13 or Windows Server 2022."
  }
}
variable "windows_admin_password" {
  description = "Administrator password for Windows Server 2022"
  type        = string
  sensitive   = true
  default     = null
}

# ============================================================
# ANSIBLE SSH PUBLIC KEY - DEBIAN 13
# ============================================================

variable "ansible_ssh_public_key" {
  description = "SSH public key used by Ansible to access Debian VMs"
  type        = string
  default     = null
}
