#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$script_dir/validate-request.sh"
bash "$script_dir/terraform-init.sh"
cd "$TF_WORKDIR"

# Plan JSON contains sensitive VM configuration: never print or publish it.
cleanup_tmp() {
  rm -f datastore-refresh.tfplan datastore-refresh.json resize-plan.json
}
trap cleanup_tmp EXIT

echo "VM resize request: ${TF_VAR_vm_name} | CPU ${TF_VAR_vm_cpu} | RAM ${TF_VAR_vm_memory} MB"
echo "Jira issue: ${JIRA_ISSUE_KEY:-not-provided}"

# Preserve state-derived inputs; never guess hostname, network, or OS.
TF_VAR_vm_hostname="$(terraform output -raw vm_hostname)"
TF_VAR_vm_network="$(terraform output -raw vm_network)"
if [[ -z "$TF_VAR_vm_hostname" || -z "$TF_VAR_vm_network" ]]; then
  echo 'ERROR: Missing VM hostname or network from Terraform state' >&2
  exit 1
fi
export TF_VAR_vm_hostname TF_VAR_vm_network

if terraform state list | grep -Fxq 'data.vsphere_virtual_machine.windows_template[0]'; then
  export TF_VAR_vm_os='Windows Server 2022'
elif terraform state list | grep -Fxq 'data.vsphere_virtual_machine.template'; then
  export TF_VAR_vm_os='Debian 13'
else
  echo 'ERROR: Cannot determine Windows/Debian template from Terraform state' >&2
  exit 1
fi
VM_RESOURCE='module.vm.vsphere_virtual_machine.vm'
if ! terraform state list | grep -Fxq "$VM_RESOURCE"; then
  echo 'ERROR: Expected module-based VM is not in this state file' >&2
  exit 1
fi
STATE_VM_NAME="$(terraform state show -no-color "$VM_RESOURCE" |
  sed -n 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' | head -1)"
if [[ -z "$STATE_VM_NAME" || "$STATE_VM_NAME" != "$TF_VAR_vm_name" ]]; then
  echo "ERROR: VM in state ($STATE_VM_NAME) differs from request ($TF_VAR_vm_name)" >&2
  exit 1
fi

# A refresh-only PLAN checks live vSphere while changing neither state nor VM.
terraform plan -refresh-only -input=false -no-color \
  -out=datastore-refresh.tfplan > /dev/null
terraform show -json datastore-refresh.tfplan > datastore-refresh.json
TF_VAR_vm_datastore_id="$(python3 "$script_dir/discover-datastore.py" datastore-refresh.json)"
export TF_VAR_vm_datastore_id
rm -f datastore-refresh.tfplan datastore-refresh.json
echo "VM verified; preserving live datastore: $TF_VAR_vm_datastore_id"

# Save the exact approved plan, then fail closed on any non-CPU/RAM change.
terraform plan -input=false -out=resize.tfplan
terraform show -json resize.tfplan > resize-plan.json
python3 "$script_dir/validate-resize-plan.py" resize-plan.json
printf '%s\n' 'Resize plan validated; awaiting Azure DevOps environment approval.'
