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
# ============================================================

resource "vsphere_virtual_machine" "jira_vm" {
  name             = var.vm_name
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = var.vm_cpu
  memory   = var.vm_memory

  guest_id  = data.vsphere_virtual_machine.template.guest_id
  firmware  = "efi"
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks[0].size
    thin_provisioned = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  extra_config = {
    "guestinfo.metadata" = base64encode(
      yamlencode({
        "instance-id"    = lower(var.vm_name)
        "local-hostname" = var.vm_hostname
      })
    )

    "guestinfo.metadata.encoding" = "base64"
  }
}
