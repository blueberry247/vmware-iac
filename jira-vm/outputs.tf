# ============================================================
# Jira VM Outputs
# Values returned from the reusable VMware VM module
# ============================================================

output "vm_name" {
  description = "Name of the VM created from the Jira request"
  value       = module.vm.vm_name
}

output "vm_ip_address" {
  description = "IP address assigned to the VM"
  value       = module.vm.vm_ip_address
}

output "vm_uuid" {
  description = "vSphere UUID of the VM"
  value       = module.vm.vm_uuid
}
