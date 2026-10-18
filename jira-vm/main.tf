# ============================================================
# Jira VM Provisioning
# One Terraform state per requested VM
# ============================================================

terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatevmware247"
    container_name       = "tfstate"

    # The state key will be supplied by Azure DevOps:
    # jira-vms/<VM-NAME>.tfstate
    use_azuread_auth = true
  }
}

# ============================================================
# vSphere Provider
# ============================================================

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

# ============================================================
# Existing vSphere Infrastructure
# ============================================================

data "vsphere_datacenter" "dc" {
  name = "FB-Datacentre"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "Cluster-1"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.vm_network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = "DEBIAN13-CLOUDINIT-TEMPLATE-V2"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ============================================================
# WINDOWS SERVER 2022 GOLDEN TEMPLATE
# ============================================================
#
# Locate the Windows Server 2022 template in vCenter.
#
# Datacenter: FB-Datacentre
# Folder:     FB-Datacentre/Windows-Templates
# Template:   WIN2022-TEMPLATE
#
# This template will be used whenever Jira requests
# Windows Server 2022.
#
# ============================================================

data "vsphere_virtual_machine" "windows_template" {

  # Only search for this template when Windows is requested
  count = var.vm_os == "Windows Server 2022" ? 1 : 0

  # Full inventory path relative to the datacenter
  name = "FB-Datacentre/Windows-Templates/WIN2022-TEMPLATE"

  # VMware datacenter containing the template
  datacenter_id = data.vsphere_datacenter.dc.id

}

# ============================================================
# Windows Server 2022 Datastore
# ============================================================

data "vsphere_datastore" "windows_datastore" {
  count         = var.vm_os == "Windows Server 2022" ? 1 : 0
  name          = "Esxi-1-142GB"
  datacenter_id = data.vsphere_datacenter.dc.id
}


# ============================================================
# Jira Requested VM
# Provisioned using the reusable VMware VM module
# ============================================================

module "vm" {
  source = "../modules/vm"

  # Jira requested values
  vm_name                = var.vm_name
  vm_hostname            = var.vm_hostname
  vm_cpu                 = var.vm_cpu
  vm_memory              = var.vm_memory
  vm_os                  = var.vm_os
  windows_admin_password = var.windows_admin_password
  ansible_ssh_public_key = var.ansible_ssh_public_key

  # Existing vSphere infrastructure
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = local.selected_datastore_id
  network_id       = data.vsphere_network.network.id

  # Automatically select the correct golden template
  template_id                    = local.selected_template.id
  template_guest_id              = local.selected_template.guest_id
  template_scsi_type             = local.selected_template.scsi_type
  template_network_adapter_type  = local.selected_template.network_interface_types[0]
  template_disk_size             = local.selected_template.disks[0].size
  template_disk_thin_provisioned = local.selected_template.disks[0].thin_provisioned
}

# ============================================================
# AUTOMATIC OS SELECTION - WINDOWS OR DEBIAN
# ============================================================

locals {
  is_windows = var.vm_os == "Windows Server 2022"

  # Select the correct VMware template
  selected_template = local.is_windows ? (
    data.vsphere_virtual_machine.windows_template[0]
  ) : data.vsphere_virtual_machine.template

  # Select the correct datastore
  selected_datastore_id = var.vm_datastore_id != null ? var.vm_datastore_id : (
    local.is_windows ? (
      data.vsphere_datastore.windows_datastore[0].id
    ) : data.vsphere_datastore.datastore.id
  )
}
