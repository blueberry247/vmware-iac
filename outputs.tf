output "datacenter_id" {
  description = "vSphere Datacenter ID"
  value       = data.vsphere_datacenter.dc.id
}

output "cluster_id" {
  description = "vSphere Cluster ID"
  value       = data.vsphere_compute_cluster.cluster.id
}

output "datastore_id" {
  description = "vSphere Datastore ID"
  value       = data.vsphere_datastore.datastore.id
}

output "network_id" {
  description = "vSphere Network ID"
  value       = data.vsphere_network.network.id
}

output "template_id" {
  description = "Golden template UUID"
  value       = data.vsphere_virtual_machine.template.id
}

output "vm_name" {
  description = "Name of the Terraform-created VM"
  value       = vsphere_virtual_machine.vm.name
}

output "vm_uuid" {
  description = "UUID of the Terraform-created VM"
  value       = vsphere_virtual_machine.vm.uuid
}

output "vm_ip_address" {
  description = "IP address reported by VMware Tools"
  value       = vsphere_virtual_machine.vm.default_ip_address
}