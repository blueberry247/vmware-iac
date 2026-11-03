# ==============================================
# VMWARE CMDB INVENTORY EXPORT
# VMware vCenter -> CSV -> Jira Assets
# ==============================================

$ErrorActionPreference = "Stop"

# Load VMware PowerCLI
Import-Module VMware.VimAutomation.Core

# Ensure we are connected to vCenter
if (-not $global:DefaultVIServers) {
    throw "Not connected to vCenter."
}

# CSV output location
$csv = "/home/bardfox/vmware-cmdb/vmware-cmdb-full-with-disk.csv"

# Retrieve VMware inventory
$inventory = @(
    Get-VM |
    Where-Object { $_.Name -notlike "vCLS-*" } |
    Sort-Object Name |
    ForEach-Object {

        $vm = $_

        # Calculate total disk capacity
        $disk = (
            Get-HardDisk -VM $vm |
            Measure-Object CapacityGB -Sum
        ).Sum

        # Retrieve VM networks
        $networks = @(
            Get-NetworkAdapter -VM $vm |
            Where-Object { $_.NetworkName } |
            Select-Object -ExpandProperty NetworkName -Unique
        )

        # Avoid guessing when multiple networks exist
        $network = if ($networks.Count -eq 1) {
            $networks[0]
        } else {
            Write-Warning "$($vm.Name): Check network configuration"
            ""
        }

        # Convert VMware power state
        $power = switch ($vm.PowerState.ToString()) {
            "PoweredOn"  { "Powered On" }
            "PoweredOff" { "Powered Off" }
            "Suspended"  { "Suspended" }
            default     { $vm.PowerState.ToString() }
        }

        # Create CSV record
        [PSCustomObject]@{
            Name       = $vm.Name
            ESXiHost   = $vm.VMHost.Name
            Datastore  = $vm.ExtensionData.Config.Files.VmPathName -replace '^\[([^\]]+)\].*', '$1'
            NumCpu     = $vm.NumCpu
            MemoryGB   = $vm.MemoryGB
            DiskSizeGB = $disk
            Network    = $network
            PowerState = $power
            CMDBStatus = "Present in VMware"
        }
    }
)

# Prevent an empty inventory from replacing the CSV
if ($inventory.Count -eq 0) {
    throw "No virtual machines found. CSV not updated."
}

# Export inventory
$inventory | Export-Csv $csv -NoTypeInformation -Encoding UTF8

Write-Host "VMware inventory export completed."
Write-Host "VMs exported: $($inventory.Count)"
Write-Host "CSV created: $csv"
