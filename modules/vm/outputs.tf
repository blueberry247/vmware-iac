output "vm_name" {
  description = "Name of the provisioned virtual machine"
  value       = vsphere_virtual_machine.vm.name
}

output "vm_id" {
  description = "vSphere ID of the provisioned virtual machine"
  value       = vsphere_virtual_machine.vm.id
}

output "vm_uuid" {
  description = "vSphere UUID of the provisioned virtual machine"
  value       = vsphere_virtual_machine.vm.uuid
}

output "vm_ip_address" {
  description = "Default IP address reported by VMware Tools"
  value       = vsphere_virtual_machine.vm.default_ip_address
}
