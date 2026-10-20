#!/usr/bin/env bash
set -euo pipefail

: "${TF_VAR_vm_name:?VM name missing}"
: "${TF_VAR_vm_cpu:?CPU count missing}"
: "${TF_VAR_vm_memory:?Memory in MB missing}"

# Never allow path separators or '..' inside a per-VM state key.
if [[ ! "$TF_VAR_vm_name" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]]; then
  echo 'ERROR: Invalid VM name from Jira.' >&2
  exit 1
fi
if [[ ! "$TF_VAR_vm_cpu" =~ ^[0-9]+$ ]] || [[ ! "$TF_VAR_vm_memory" =~ ^[0-9]+$ ]]; then
  echo 'ERROR: CPU and RAM must be whole numbers.' >&2
  exit 1
fi
if (( 10#$TF_VAR_vm_cpu < 1 || 10#$TF_VAR_vm_memory < 1 )); then
  echo 'ERROR: CPU and RAM must be greater than zero.' >&2
  exit 1
fi
