#!/usr/bin/env bash
set -euo pipefail
umask 077
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

: "${TF_WORKDIR:?Missing Terraform workdir}"
: "${TF_VAR_vm_name:?Missing VM name}"
: "${JIRA_ISSUE_KEY:?Missing Jira issue key}"
: "${TF_PLAN_PASSPHRASE:?Missing plan passphrase}"
[[ "$TF_VAR_vm_name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]] || {
  echo 'ERROR: Invalid VM name; refusing to open a state file.' >&2; exit 1;
}
[[ "$JIRA_ISSUE_KEY" =~ ^[A-Z][A-Z0-9_]*-[0-9]+$ ]] || {
  echo 'ERROR: Invalid Jira issue key.' >&2; exit 1;
}
cd "$TF_WORKDIR"
rm -f destroy.tfplan destroy.tfplan.gpg
finished=false
cleanup() {
  rm -f destroy.tfplan
  if [[ "$finished" != true ]]; then rm -f destroy.tfplan.gpg; fi
}
trap cleanup EXIT

terraform init -input=false -reconfigure \
  -backend-config="key=jira-vms/${TF_VAR_vm_name}.tfstate"

# Inspect raw state in memory, without printing credentials to logs.
# Produces a validated resource address and OS; no pipelines or grep -q.
state_info="$(python3 "$script_dir/decommission-verify-state.py" "$TF_VAR_vm_name")"
IFS=$'\t' read -r vm_resource detected_os <<< "$state_info"
[[ -n "$vm_resource" && -n "$detected_os" ]] || {
  echo 'ERROR: Could not establish VM resource and OS.' >&2; exit 1;
}
export TF_VAR_vm_os="$detected_os"
printf 'Verified VM: %s | resource: %s | OS: %s\n' \
  "$TF_VAR_vm_name" "$vm_resource" "$TF_VAR_vm_os"

terraform plan -destroy -input=false -no-color -out=destroy.tfplan
python3 "$script_dir/decommission-validate-plan.py" destroy.tfplan "$vm_resource" "$TF_VAR_vm_name"

printf '%s' "$TF_PLAN_PASSPHRASE" | \
  gpg --batch --yes --pinentry-mode loopback \
    --passphrase-fd 0 --symmetric --cipher-algo AES256 \
    --output destroy.tfplan.gpg destroy.tfplan
chmod 600 destroy.tfplan.gpg
finished=true
echo 'Validated, encrypted exact destroy plan. Awaiting VMware-Production approval.'
