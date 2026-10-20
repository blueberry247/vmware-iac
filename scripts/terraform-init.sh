#!/usr/bin/env bash
# Reusable initialization for ONE VM's remote state.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$script_dir/validate-request.sh"
: "${TF_WORKDIR:?Missing Terraform working directory}"
if [[ ! -d "$TF_WORKDIR" ]]; then
  echo "ERROR: Terraform working directory not found: $TF_WORKDIR" >&2
  exit 1
fi
cd "$TF_WORKDIR"
terraform init -input=false -reconfigure \
  -backend-config="key=jira-vms/${TF_VAR_vm_name}.tfstate"
