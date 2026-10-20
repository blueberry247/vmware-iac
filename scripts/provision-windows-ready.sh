#!/usr/bin/env bash
set -euo pipefail

echo "===================================="
echo "ANSIBLE WINDOWS CONFIGURATION"
echo "===================================="

: "${VM_IP:?Missing VM IP address}"
: "${WINDOWS_ADMIN_PASSWORD:?Missing Windows Administrator password}"

echo "Target VM IP: $VM_IP"
echo "Connecting to ANSIBLE-01..."

# Send Ansible connection settings securely over SSH.
# Password is not included in command-line arguments.

python3 - <<'PY' | ssh \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=yes \
  bardfox@192.168.1.113 '
    set -eu
    umask 077

    varsfile=$(mktemp)

    trap "rm -f \"$varsfile\"" EXIT

    cat > "$varsfile"

    ansible-playbook \
      -i "provisioned-windows," \
      /home/bardfox/ansible-provisioning/windows-ready.yml \
      -e "@$varsfile"
  '
import json
import os

print(json.dumps({
    "ansible_host": os.environ["VM_IP"],
    "ansible_connection": "winrm",
    "ansible_user": "Administrator",
    "ansible_port": 5985,
    "ansible_winrm_transport": "ntlm",
    "ansible_winrm_message_encryption": "always",
    "ansible_password": os.environ["WINDOWS_ADMIN_PASSWORD"]
}))
PY

echo "===================================="
echo "ANSIBLE WINDOWS CHECK COMPLETED"
echo "===================================="
