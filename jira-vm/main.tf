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
  name          = "Deb-01-template-v3"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ============================================================
# Jira Requested VM
# Provisioned using the reusable VMware VM module
# ============================================================

module "vm" {
  source = "../modules/vm"

  # Jira requested values
  vm_name     = var.vm_name
  vm_hostname = var.vm_hostname
  vm_cpu      = var.vm_cpu
  vm_memory   = var.vm_memory

  # Existing vSphere infrastructure
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  network_id       = data.vsphere_network.network.id

  # Golden template configuration
  template_id                    = data.vsphere_virtual_machine.template.id
  template_guest_id              = data.vsphere_virtual_machine.template.guest_id
  template_scsi_type             = data.vsphere_virtual_machine.template.scsi_type
  template_network_adapter_type  = data.vsphere_virtual_machine.template.network_interface_types[0]
  template_disk_size             = data.vsphere_virtual_machine.template.disks[0].size
  template_disk_thin_provisioned = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
}