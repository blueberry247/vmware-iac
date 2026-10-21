#!/usr/bin/env bash

set -e


cd "$TF_WORKING_DIR"


# Protect temporary Terraform plan files
umask 077

# Remove any old plan files
rm -f tfplan tfplan.gpg

# Always remove the unencrypted plan when the task exits
trap 'rm -f tfplan' EXIT

echo "===================================="
echo "VM Request"
echo "===================================="
echo "Jira:     $JIRA_ISSUE_KEY"
echo "Name:     $TF_VAR_vm_name"
echo "Hostname: $TF_VAR_vm_hostname"
echo "CPU:      $TF_VAR_vm_cpu"
echo "Memory:   $TF_VAR_vm_memory"
echo "Network:  $TF_VAR_vm_network"
echo "===================================="

# Each Jira VM gets its own Terraform state.
terraform init \
  -reconfigure \
  -backend-config="key=jira-vms/${TF_VAR_vm_name}.tfstate"

terraform validate

# Exit codes:
# 0 = no changes
# 1 = error
# 2 = changes found

set +e

terraform plan \
  -input=false \
  -detailed-exitcode \
  -out=tfplan

PLAN_EXIT_CODE=$?

set -e

if [ "$PLAN_EXIT_CODE" -eq 0 ]; then

  echo "No Terraform changes detected."

  echo "##vso[task.setvariable variable=changesDetected;isOutput=true]false"

elif [ "$PLAN_EXIT_CODE" -eq 2 ]; then

  echo "Terraform changes detected."

  echo "##vso[task.setvariable variable=changesDetected;isOutput=true]true"

else

  echo "Terraform plan failed."

  exit "$PLAN_EXIT_CODE"

fi

# ============================================
# Encrypt Terraform plan before publishing
# ============================================

if [ "$PLAN_EXIT_CODE" -eq 2 ]; then

  echo "Encrypting Terraform plan..."

  # Ensure an encryption passphrase is available
  : "${TF_PLAN_PASSPHRASE:?Missing Terraform plan encryption passphrase}"

  # Remove plaintext plan when this script exits
  trap 'rm -f tfplan' EXIT

  # Encrypt using AES-256
  printf '%s' "$TF_PLAN_PASSPHRASE" | \
    gpg --batch --yes \
    --pinentry-mode loopback \
    --passphrase-fd 0 \
    --symmetric \
    --cipher-algo AES256 \
    --output tfplan.gpg \
    tfplan

  # Delete the unencrypted plan
  rm -f tfplan

  echo "Terraform plan encrypted successfully."

fi
