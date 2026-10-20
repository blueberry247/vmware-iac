#!/usr/bin/env bash
set -euo pipefail
umask 077
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

: "${TF_WORKDIR:?Missing Terraform workdir}"
: "${APPROVED_PLAN:?Missing approved encrypted plan path}"
: "${TF_PLAN_PASSPHRASE:?Missing plan passphrase}"
: "${TF_VAR_vm_name:?Missing VM name}"
: "${JIRA_ISSUE_KEY:?Missing Jira issue key}"
[[ "$TF_VAR_vm_name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]] || {
  echo 'ERROR: Invalid VM name.' >&2; exit 1;
}
[[ "$JIRA_ISSUE_KEY" =~ ^[A-Z][A-Z0-9_]*-[0-9]+$ ]] || {
  echo 'ERROR: Invalid Jira issue key.' >&2; exit 1;
}
[[ -f "$APPROVED_PLAN" ]] || { echo 'ERROR: Approved encrypted plan not found.' >&2; exit 1; }
cd "$TF_WORKDIR"
trap 'rm -f destroy.tfplan' EXIT
rm -f destroy.tfplan
terraform init -input=false -reconfigure \
  -backend-config="key=jira-vms/${TF_VAR_vm_name}.tfstate"
state_info="$(python3 "$script_dir/decommission-verify-state.py" "$TF_VAR_vm_name")"
IFS=$'\t' read -r vm_resource detected_os <<< "$state_info"
export TF_VAR_vm_os="$detected_os"

printf '%s' "$TF_PLAN_PASSPHRASE" | \
  gpg --batch --yes --pinentry-mode loopback \
    --passphrase-fd 0 --decrypt --output destroy.tfplan "$APPROVED_PLAN"
chmod 600 destroy.tfplan
# Double-check artifact has only the expected VM delete before applying.
python3 "$script_dir/decommission-validate-plan.py" destroy.tfplan "$vm_resource" "$TF_VAR_vm_name"
terraform apply -input=false destroy.tfplan

# A successful apply should remove the VM's managed state record.
post_state="$(terraform state list)"
if grep -Fxq "$vm_resource" <<< "$post_state"; then
  echo 'ERROR: VM still appears in Terraform state after apply.' >&2
  exit 1
fi
printf 'VM decommission complete: %s. Terraform state verified.\n' "$TF_VAR_vm_name"
