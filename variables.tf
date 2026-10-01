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

# ============================================================
# VMware VM Factory
# ============================================================

variable "virtual_machines" {
  description = "Virtual machines to provision in vSphere"

  type = map(object({
    cpu      = number
    memory   = number
    hostname = string
  }))

  default = {
    "TF-VM-005" = {
      cpu      = 2
      memory   = 2048
      hostname = "tf-vm-005"
    }

    "TF-VM-006" = {
      cpu      = 2
      memory   = 4096
      hostname = "tf-vm-006"
    }
  }
}

