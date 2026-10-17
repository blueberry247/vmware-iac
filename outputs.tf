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
