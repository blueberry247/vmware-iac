#!/usr/bin/env bash
set -euo pipefail

: "${TF_VAR_vm_name:?Missing VM name}"
cd "$TF_WORKING_DIR"
terraform init \
  -reconfigure \
  -backend-config="key=jira-vms/${TF_VAR_vm_name}.tfstate"

VM_IP=$(terraform output -raw vm_ip_address)
# Fail closed on missing or malformed IPv4 addresses.
python3 - "$VM_IP" <<'PYIP'
import ipaddress, sys
try:
    value = ipaddress.ip_address(sys.argv[1])
    assert isinstance(value, ipaddress.IPv4Address)
    assert not value.is_unspecified and not value.is_multicast
except (ValueError, AssertionError):
    sys.exit('ERROR: VM state does not contain a valid IPv4 address')
PYIP
echo "VM IP Address: $VM_IP"
echo "##vso[task.setvariable variable=PROVISIONED_VM_IP]$VM_IP"
