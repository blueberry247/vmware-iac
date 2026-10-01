terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.5.0"

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatevmware247"
    container_name       = "tfstate"
    key                  = "vmware-iac.tfstate"
    use_azuread_auth     = true
  }
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}