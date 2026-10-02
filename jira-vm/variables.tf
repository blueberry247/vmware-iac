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
