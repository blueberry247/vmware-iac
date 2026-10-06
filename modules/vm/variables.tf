variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_hostname" {
  description = "Hostname configured inside the guest OS"
  type        = string
}

variable "vm_cpu" {
  description = "Number of virtual CPUs"
  type        = number
}

variable "vm_memory" {
  description = "Memory allocated to the VM in MB"
  type        = number
}

variable "resource_pool_id" {
  description = "vSphere resource pool ID"
  type        = string
}

variable "datastore_id" {
  description = "vSphere datastore ID"
  type        = string
}

variable "network_id" {
  description = "vSphere network ID"
  type        = string
}

variable "template_id" {
  description = "UUID of the vSphere VM template"
  type        = string
}

variable "template_guest_id" {
  description = "Guest OS ID inherited from the template"
  type        = string
}

variable "template_scsi_type" {
  description = "SCSI controller type inherited from the template"
  type        = string
}

variable "template_network_adapter_type" {
  description = "Network adapter type inherited from the template"
  type        = string
}

variable "template_disk_size" {
  description = "Disk size inherited from the template"
  type        = number
}

variable "template_disk_thin_provisioned" {
  description = "Whether the template disk uses thin provisioning"
  type        = bool
}
