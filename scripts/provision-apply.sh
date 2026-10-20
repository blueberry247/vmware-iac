#!/usr/bin/env bash

set -e


cd "$TF_WORKING_DIR"

# Protect decrypted Terraform plan
umask 077

# Remove any leftover plaintext plan
rm -f tfplan

# Connect to the same state used during Plan.
terraform init \
  -reconfigure \
  -backend-config="key=jira-vms/${TF_VAR_vm_name}.tfstate"


# ============================================
# Decrypt the approved Terraform plan
# ============================================

echo "Decrypting approved Terraform plan..."

: "${TF_PLAN_PASSPHRASE:?Missing Terraform plan encryption passphrase}"


# Remove decrypted plan when the task exits
trap 'rm -f tfplan' EXIT

printf '%s' "$TF_PLAN_PASSPHRASE" | \
 gpg --batch --yes \
 --pinentry-mode loopback \
 --passphrase-fd 0 \
 --decrypt \
 --output tfplan \
 "$PLAN_ARTIFACT_FILE"

 chmod 600 tfplan

 echo "Terraform plan decrypted successfully."


# Apply the decrypted Terraform plan
terraform apply \
  -input=false \
  tfplan


echo ""
echo "===================================="
echo "VM CREATED"
echo "===================================="

terraform output

VM_IP=$(terraform output -raw vm_ip_address)

# Validate the IP address returned by VMware
if [ -z "${VM_IP//[[:space:]]/}" ] || [ "$VM_IP" = "0.0.0.0" ] || [ "$VM_IP" = "<nil>" ]; then
  echo "ERROR: VMware did not return a usable VM IP address."
  exit 1
fi

echo "VM IP Address: $VM_IP"

echo "##vso[task.setvariable variable=PROVISIONED_VM_IP]$VM_IP"
