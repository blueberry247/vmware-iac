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

output "vm_hostname" {
  description = "Hostname configured for the VM"
  value       = var.vm_hostname
}

output "vm_network" {
  description = "Network configured for the VM"
  value       = var.vm_network
}

output "vm_cpu" {
  description = "CPU configured for the VM"
  value       = var.vm_cpu
}

output "vm_memory" {
  description = "Memory configured for the VM in MB"
  value       = var.vm_memory
}