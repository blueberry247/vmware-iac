#!/usr/bin/env bash
set -euo pipefail
umask 077

echo "===================================="
echo "DEBIAN SSH HOST KEY REGISTRATION"
echo "===================================="

: "${VM_NAME:?Missing VM name}"
: "${VM_IP:?Missing VM IP}"
: "${GOVC_URL:?Missing vCenter server}"
: "${GOVC_USERNAME:?Missing vCenter username}"
: "${GOVC_PASSWORD:?Missing vCenter password}"
: "${GOVC_GUEST_LOGIN:?Missing Debian guest credentials}"

# Ensure vCenter certificate verification stays enabled.
unset GOVC_INSECURE

# Prevent unsafe values being used in remote commands.
[[ "$VM_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
[[ "$BUILD_ID" =~ ^[0-9]+$ ]] || exit 1

GOVC=/home/bardfox/tools/govc/govc

HOST_KEY_FILE=$(mktemp)
trap 'rm -f "$HOST_KEY_FILE"' EXIT

echo "Retrieving SSH host key for $VM_NAME"

# Download the public host key through VMware Guest Operations.
# Retry while the newly provisioned VM finishes starting.
downloaded=false

for attempt in $(seq 1 12); do
  if "$GOVC" guest.download \
    -f \
    -vm="$VM_NAME" \
    /etc/ssh/ssh_host_ed25519_key.pub \
    "$HOST_KEY_FILE"; then
    downloaded=true
    break
  fi

  echo "Waiting for VMware Guest Operations ($attempt/12)"
  rm -f "$HOST_KEY_FILE"
  sleep 10
done

if [[ "$downloaded" != true ]]; then
  echo "ERROR: Could not retrieve Debian SSH host key."
  exit 1
fi

# Verify that the downloaded file contains an ED25519 public key.
ssh-keygen -lf "$HOST_KEY_FILE"
grep -q '^ssh-ed25519 ' "$HOST_KEY_FILE"

echo "Transferring verified SSH key to ANSIBLE-01"

REMOTE_FILE="/home/bardfox/debian-host-key-${BUILD_ID}.pub"

scp \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=yes \
  "$HOST_KEY_FILE" \
  "bardfox@192.168.1.113:$REMOTE_FILE"

echo "Registering SSH host key on ANSIBLE-01"

ssh \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=yes \
  bardfox@192.168.1.113 \
  "bash -s -- '$VM_IP' '$BUILD_ID'" <<'REMOTE'
set -euo pipefail
umask 077

VM_IP="$1"
BUILD_ID="$2"

KEY_FILE="$HOME/debian-host-key-${BUILD_ID}.pub"
trap 'rm -f "$KEY_FILE"' EXIT

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/known_hosts"

# Prevent concurrent pipeline runs changing known_hosts together.
(
  flock -x 9

  ssh-keygen -R "$VM_IP" \
    -f "$HOME/.ssh/known_hosts" >/dev/null 2>&1 || true

  awk -v ip="$VM_IP" '
    $1 == "ssh-ed25519" {
      print ip, $1, $2
    }
  ' "$KEY_FILE" >> "$HOME/.ssh/known_hosts"

  chmod 600 "$HOME/.ssh/known_hosts"

) 9>"$HOME/.ssh/known_hosts.lock"

echo "Debian SSH host key registered successfully."
REMOTE

echo "===================================="
echo "SSH HOST KEY REGISTRATION COMPLETED"
echo "===================================="
