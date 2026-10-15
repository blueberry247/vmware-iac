# ============================================================
# TERRAFORM - VMWARE VIRTUAL MACHINE PROVISIONING MODULE
# ============================================================
#
# Purpose:
# This module creates virtual machines in VMware vSphere.
#
# Supported operating systems:
#   1. Debian Linux
#   2. Windows Server 2022
#
# The operating system is selected automatically using
# the vm_os variable passed from the main Terraform project.
#
# Automation workflow:
#
# Jira Request
#      |
#      v
# Azure DevOps Pipeline
#      |
#      v
# Terraform
#      |
#      v
# VMware vCenter
#      |
#      v
# Virtual Machine Created
#
# ============================================================


# ============================================================
# 1. CREATE VMWARE VIRTUAL MACHINE
# ============================================================
#
# This resource instructs Terraform to create and manage
# a virtual machine in VMware vSphere.
#
# "vm" is Terraform's internal resource name.
#
# ============================================================

resource "vsphere_virtual_machine" "vm" {

  # ----------------------------------------------------------
  # VIRTUAL MACHINE NAME
  # ----------------------------------------------------------
  #
  # Name displayed in VMware vCenter.
  #
  # Example:
  # WIN-SRV-001
  # DEB-SRV-001
  #
  # The name is supplied through the Jira request.
  #
  name = var.vm_name


  # ----------------------------------------------------------
  # RESOURCE POOL
  # ----------------------------------------------------------
  #
  # Determines which VMware resource pool will host the VM.
  #
  # The resource pool ID is retrieved from the VMware cluster
  # in the parent Terraform configuration.
  #
  resource_pool_id = var.resource_pool_id


  # ----------------------------------------------------------
  # DATASTORE
  # ----------------------------------------------------------
  #
  # Determines where the virtual machine files are stored.
  #
  # Debian:
  #   vsanDatastore
  #
  # Windows:
  #   Esxi-1-142GB
  #
  # The parent Terraform configuration automatically
  # selects the correct datastore.
  #
  datastore_id = var.datastore_id


  # ==========================================================
  # 2. CPU AND MEMORY CONFIGURATION
  # ==========================================================
  #
  # These values are supplied through Jira.
  #
  # Example:
  # CPU = 2
  # RAM = 4096 MB
  #
  # vm_memory is measured in megabytes.
  #
  # ==========================================================

  num_cpus = var.vm_cpu

  memory = var.vm_memory


  # ==========================================================
  # 3. VALIDATE WINDOWS ADMINISTRATOR PASSWORD
  # ==========================================================
  #
  # This lifecycle precondition checks whether Windows
  # Server 2022 has an Administrator password configured.
  #
  # If Windows is selected:
  #   The password must not be null or empty.
  #
  # If Debian is selected:
  #   This password check is skipped.
  #
  # If the check fails:
  #   Terraform stops with the error message below.
  #
  # IMPORTANT:
  #   The password should be supplied securely through
  #   Azure DevOps rather than hardcoded into Terraform.
  #
  # ==========================================================

  lifecycle {

    # Windows Server 2022 requires an Administrator password
    precondition {
      condition = var.vm_os == "Windows Server 2022" ? (
        var.windows_admin_password != null ?
        length(trimspace(var.windows_admin_password)) > 0 : false
      ) : true

      error_message = "Windows Server 2022 requires an Administrator password."
    }

    # Debian 13 requires an Ansible SSH public key
    precondition {
      condition = var.vm_os == "Debian 13" ? (
        var.ansible_ssh_public_key != null ?
        length(trimspace(var.ansible_ssh_public_key)) > 0 : false
      ) : true

      error_message = "Debian 13 requires an Ansible SSH public key."
    }

  }


  # ==========================================================
  # 4. ENABLE CPU AND MEMORY HOT ADD
  # ==========================================================
  #
  # CPU Hot Add:
  #   Allows additional virtual CPUs to be added while
  #   the VM is running, where supported.
  #
  # Memory Hot Add:
  #   Allows additional RAM to be added while the VM
  #   is running, where supported.
  #
  # These settings will be useful when implementing
  # our Jira VM resizing automation.
  #
  # IMPORTANT:
  #   Guest operating system support and VMware
  #   configuration determine whether a reboot is needed.
  #
  # ==========================================================

  cpu_hot_add_enabled = true

  memory_hot_add_enabled = true


  # ----------------------------------------------------------
  # VIRTUAL IOMMU / VT-d
  # ----------------------------------------------------------
  #
  # Enable virtualised I/O memory management support.
  #
  # Compatibility depends on the underlying VMware
  # environment and guest operating system.
  #
  vvtd_enabled = true


  # ==========================================================
  # 5. GUEST OPERATING SYSTEM CONFIGURATION
  # ==========================================================
  #
  # Terraform obtains the guest OS identifier from the
  # selected VMware golden template.
  #
  # Examples:
  #   Windows Server 2022
  #   Debian Linux
  #
  # This avoids hardcoding a guest ID for each operating
  # system inside the reusable module.
  #
  # ==========================================================

  guest_id = var.template_guest_id


  # ----------------------------------------------------------
  # VM FIRMWARE
  # ----------------------------------------------------------
  #
  # Use EFI firmware rather than legacy BIOS.
  #
  # The golden templates must support EFI.
  #
  firmware = "efi"


  # ----------------------------------------------------------
  # SCSI CONTROLLER TYPE
  # ----------------------------------------------------------
  #
  # Use the SCSI controller type from the selected template.
  #
  # Examples:
  #   pvscsi
  #   lsilogic-sas
  #
  scsi_type = var.template_scsi_type


  # ==========================================================
  # 6. VIRTUAL MACHINE NETWORK CONFIGURATION
  # ==========================================================
  #
  # Connect the VM to the network selected in Jira.
  #
  # network_id:
  #   VMware network / distributed port group ID.
  #
  # adapter_type:
  #   Network adapter type from the golden template.
  #
  # Example:
  #   vmxnet3
  #
  # ==========================================================

  network_interface {

    network_id = var.network_id

    adapter_type = var.template_network_adapter_type

  }


  # ==========================================================
  # 7. VIRTUAL MACHINE DISK CONFIGURATION
  # ==========================================================
  #
  # Configure the VM's primary virtual disk.
  #
  # label:
  #   VMware disk label.
  #
  # size:
  #   Disk size in GB, obtained from the golden template.
  #
  # thin_provisioned:
  #   Use the provisioning type of the golden template.
  #
  # IMPORTANT:
  #   This currently uses the template's disk size.
  #   It does not yet accept a separate disk-size request
  #   from Jira.
  #
  # ==========================================================

  disk {

    label = "disk0"

    size = var.template_disk_size

    thin_provisioned = var.template_disk_thin_provisioned

  }


  # ==========================================================
  # 8. CLONE VIRTUAL MACHINE FROM GOLDEN TEMPLATE
  # ==========================================================
  #
  # Rather than installing the operating system manually,
  # Terraform clones an existing VMware template.
  #
  # The parent configuration selects the correct template:
  #
  # Debian:
  #   Deb-01-template-v3
  #
  # Windows Server 2022:
  #   WIN2022-TEMPLATE
  #
  # template_id contains the selected template's VMware UUID.
  #
  # ==========================================================

  clone {

    template_uuid = var.template_id


    # ========================================================
    # 9. WINDOWS SERVER 2022 GUEST CUSTOMISATION
    # ========================================================
    #
    # Guest customisation configures Windows after the
    # virtual machine has been cloned.
    #
    # The dynamic block is conditional.
    #
    # If vm_os == "Windows Server 2022":
    #   Create one Windows customisation block.
    #
    # If vm_os == "Debian":
    #   Do not create this Windows customisation block.
    #
    # The expression:
    #
    # [1] = Enable the block
    # []  = Disable the block
    #
    # ========================================================

    dynamic "customize" {

      for_each = var.vm_os == "Windows Server 2022" ? [1] : []

      content {


        # ----------------------------------------------------
        # WINDOWS OPERATING SYSTEM SETTINGS
        # ----------------------------------------------------
        #
        # computer_name:
        #   Sets the Windows computer name.
        #
        # Example:
        #   WIN-SRV-001
        #
        # admin_password:
        #   Sets the local Windows Administrator password.
        #
        # workgroup:
        #   Places the Windows machine into WORKGROUP.
        #
        # Later, we can extend our automation to join
        # Windows servers to the Active Directory domain.
        #
        # ----------------------------------------------------

        windows_options {

          computer_name = var.vm_hostname

          admin_password = var.windows_admin_password

          workgroup = "WORKGROUP"

        }


        # ----------------------------------------------------
        # WINDOWS NETWORK CONFIGURATION
        # ----------------------------------------------------
        #
        # An empty network_interface customisation block
        # tells VMware to configure the network using DHCP.
        #
        # The DHCP server will provide the VM with:
        #
        #   - IP address
        #   - Subnet mask
        #   - Default gateway
        #
        # DNS settings depend on the DHCP configuration.
        #
        # We can add static IP configuration later.
        #
        # ----------------------------------------------------

        network_interface {}

      }

    }

  }

  # ============================================================
  # DEBIAN 13 - CLOUD-INIT AND ANSIBLE SSH ACCESS
  # ============================================================

  extra_config = var.vm_os == "Debian 13" ? merge(

    # VMware guest metadata
    {
      "guestinfo.metadata" = base64encode(yamlencode({
        "instance-id"    = lower(var.vm_name)
        "local-hostname" = var.vm_hostname
      }))

      "guestinfo.metadata.encoding" = "base64"
    },

    # Install ANSIBLE-01 SSH public key when provided
    var.ansible_ssh_public_key != null ? {

      "guestinfo.userdata" = base64encode(
        "#cloud-config\n" + yamlencode({
          users = [
            "default",
            {
              name                = "bardfox"
              ssh_authorized_keys = [var.ansible_ssh_public_key]
            }
          ]
        })
      )

      "guestinfo.userdata.encoding" = "base64"

    } : {}

  ) : {}

}