#!/usr/bin/env bash
set -euo pipefail

echo "===================================="
echo "ANSIBLE DEBIAN 13 READINESS"
echo "===================================="

: "${VM_IP:?Missing VM IP address}"

echo "Target Debian VM: $VM_IP"

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
      -i "provisioned-debian," \
      /home/bardfox/ansible-provisioning/debian-ready.yml \
      -e "@$varsfile"
  '
import json
import os

print(json.dumps({
    "ansible_host": os.environ["VM_IP"],
    "ansible_user": "bardfox",
    "ansible_connection": "ssh",
    "ansible_ssh_private_key_file": "/home/bardfox/.ssh/id_ed25519",
    "ansible_ssh_common_args": "-o StrictHostKeyChecking=yes -o BatchMode=yes"
}))
PY

echo "Debian 13 Ansible readiness completed successfully."
