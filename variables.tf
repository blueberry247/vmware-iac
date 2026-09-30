variable "vsphere_server" {
  description = "FQDN of the vCenter Server"
  type        = string
}

variable "vsphere_user" {
  description = "Username used to connect to vCenter"
  type        = string
  sensitive   = true
}

variable "vsphere_password" {
  description = "Password used to connect to vCenter"
  type        = string
  sensitive   = true
}