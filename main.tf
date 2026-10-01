# ============================================================
# VMware vSphere - Existing Infrastructure
# ============================================================

# Datacenter
data "vsphere_datacenter" "dc" {
  name = "FB-Datacentre"
}

# Cluster
data "vsphere_compute_cluster" "cluster" {
  name          = "Cluster-1"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Datastore
data "vsphere_datastore" "datastore" {
  name          = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Network
data "vsphere_network" "network" {
  name          = "NESTED-MGMT"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "nested_mgmt" {
  name          = "NESTED-MGMT"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Golden VM Template
data "vsphere_virtual_machine" "template" {
  name          = "Deb-01-template"
  datacenter_id = data.vsphere_datacenter.dc.id
}


# ============================================================
# Virtual Machine
# ============================================================

resource "vsphere_virtual_machine" "vm" {
  name             = "TF-VM-001"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = 2
  memory   = 2048
  guest_id = data.vsphere_virtual_machine.template.guest_id

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
}

resource "vsphere_virtual_machine" "vm02" {
  name             = "TF-VM-002"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = 2
  memory   = 2048

  guest_id  = data.vsphere_virtual_machine.template.guest_id
  firmware  = "efi"
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.nested_mgmt.id
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
}

# ============================================================
# Debian Golden Template V3
# ============================================================

data "vsphere_virtual_machine" "template_v3" {
  name          = "Deb-01-template-v3"
  datacenter_id = data.vsphere_datacenter.dc.id
}


# ============================================================
# Ansible Control Node
# ============================================================

resource "vsphere_virtual_machine" "ansible01" {

  # ----------------------------------------------------------
  # VM Configuration
  # ----------------------------------------------------------

  name             = "ANSIBLE-01"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = 2
  memory   = 2048


  # ----------------------------------------------------------
  # Cloud-Init via VMware GuestInfo
  # ----------------------------------------------------------

  extra_config = {

    # Cloud-init user-data
    "guestinfo.userdata" = base64encode(
      file("${path.module}/cloud-init.yaml")
    )

    "guestinfo.userdata.encoding" = "base64"

    # Cloud-init metadata
    "guestinfo.metadata" = base64encode(
      yamlencode({
        "instance-id"    = "ansible-01"
        "local-hostname" = "ansible-01"
      })
    )

    "guestinfo.metadata.encoding" = "base64"
  }


  # ----------------------------------------------------------
  # Guest OS Configuration
  # ----------------------------------------------------------

  guest_id = data.vsphere_virtual_machine.template_v3.guest_id

  firmware = "efi"

  scsi_type = data.vsphere_virtual_machine.template_v3.scsi_type


  # ----------------------------------------------------------
  # Network
  # ----------------------------------------------------------

  network_interface {
    network_id = data.vsphere_network.nested_mgmt.id

    adapter_type = data.vsphere_virtual_machine.template_v3.network_interface_types[0]
  }


  # ----------------------------------------------------------
  # Disk
  # ----------------------------------------------------------

  disk {
    label = "disk0"

    size = data.vsphere_virtual_machine.template_v3.disks[0].size

    thin_provisioned = data.vsphere_virtual_machine.template_v3.disks[0].thin_provisioned
  }


  # ----------------------------------------------------------
  # Clone From Debian Golden Template V3
  # ----------------------------------------------------------

  clone {
    template_uuid = data.vsphere_virtual_machine.template_v3.id
  }

}
