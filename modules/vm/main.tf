resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_name
  resource_pool_id = var.resource_pool_id
  datastore_id     = var.datastore_id

  num_cpus = var.vm_cpu
  memory   = var.vm_memory

  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true

  guest_id  = var.template_guest_id
  firmware  = "efi"
  scsi_type = var.template_scsi_type

  network_interface {
    network_id   = var.network_id
    adapter_type = var.template_network_adapter_type
  }

  disk {
    label            = "disk0"
    size             = var.template_disk_size
    thin_provisioned = var.template_disk_thin_provisioned
  }

  clone {
    template_uuid = var.template_id
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
