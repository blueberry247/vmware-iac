# ============================================================
# Jira VM Outputs
# ============================================================

output "vm_name" {
  description = "Name of the VM created from the Jira request"
  value       = vsphere_virtual_machine.jira_vm.name
}

output "vm_ip_address" {
  description = "IP address assigned to the VM"
  value       = vsphere_virtual_machine.jira_vm.default_ip_address
}

output "vm_uuid" {
  description = "vSphere UUID of the VM"
  value       = vsphere_virtual_machine.jira_vm.uuid
}
