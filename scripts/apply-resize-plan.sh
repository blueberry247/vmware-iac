#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$script_dir/validate-request.sh"
bash "$script_dir/terraform-init.sh"
cd "$TF_WORKDIR"
: "${APPROVED_PLAN:?Missing Azure DevOps approved plan artifact path}"
if [[ ! -s "$APPROVED_PLAN" ]]; then
  echo 'ERROR: Saved Terraform plan artifact is missing/empty' >&2
  exit 1
fi
# Apply the exact reviewed artifact; do NOT generate a fresh plan here.
cp -- "$APPROVED_PLAN" resize.tfplan
printf 'Applying approved plan for %s (CPU %s, RAM %s MB)\n' \
  "$TF_VAR_vm_name" "$TF_VAR_vm_cpu" "$TF_VAR_vm_memory"
terraform apply -input=false resize.tfplan
printf '%s\n' 'Terraform apply succeeded; Jira can now be completed.'
