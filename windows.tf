# ============================================================
# WINDOWS SERVER 2022 - VMWARE INFRASTRUCTURE
# ============================================================
#
# Purpose:
# Define the existing VMware infrastructure used for
# Windows Server 2022 virtual machine deployments.
#
# IMPORTANT:
# WIN-SRV-001 has been decommissioned and removed
# from Terraform state.
#
# We have removed its VM resource definition to prevent
# Terraform from recreating the machine.
#
# The Windows golden template and datastore remain available
# for future Terraform deployments.
#
# ============================================================


# ============================================================
# 1. WINDOWS SERVER 2022 GOLDEN TEMPLATE
# ============================================================
#
# This data source finds our existing Windows Server 2022
# template inside VMware vCenter.
#
# Datacenter: FB-Datacentre
# Folder:     FB-Datacentre/Windows-Templates
# Template:   WIN2022-TEMPLATE
#
# Terraform can use this template when provisioning
# new Windows Server 2022 virtual machines.
#
# ============================================================

data "vsphere_virtual_machine" "windows_template" {

  # Full inventory path to the Windows golden template
  name = "FB-Datacentre/Windows-Templates/WIN2022-TEMPLATE"

  # VMware datacenter containing the template
  datacenter_id = data.vsphere_datacenter.dc.id

}


# ============================================================
# 2. WINDOWS SERVER 2022 DATASTORE
# ============================================================
#
# This data source identifies the VMware datastore used
# for our Windows Server 2022 deployments.
#
# Datastore: Esxi-1-142GB
#
# IMPORTANT:
# This only references the existing datastore.
# It does not create or delete any VMware storage.
#
# ============================================================

data "vsphere_datastore" "windows_datastore" {

  # Existing datastore name
  name = "Esxi-1-142GB"

  # Datacenter containing the datastore
  datacenter_id = data.vsphere_datacenter.dc.id

}


# ============================================================
# 3. WINDOWS VM RESOURCE CLEANUP
# ============================================================
#
# The following Terraform resource has been removed:
#
# resource "vsphere_virtual_machine" "windows01"
#
# Previous VM: WIN-SRV-001
#
# Reason:
# The virtual machine was successfully decommissioned.
#
# Removing its resource definition prevents Terraform
# from attempting to recreate it during future deployments.
#
# No other VMware virtual machines are modified by
# this configuration cleanup.
#
# ============================================================