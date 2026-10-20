#!/usr/bin/env python3
"""Safely identify one VM and its OS from a single per-VM Terraform state."""
import json
import subprocess
import sys


class SafetyError(ValueError):
    pass


def verify_state(state: dict, expected_name: str) -> tuple[str, str]:
    resources = state.get('resources', [])
    candidates = []
    for resource in resources:
        if resource.get('mode') != 'managed' or resource.get('type') != 'vsphere_virtual_machine':
            continue
        address = '.'.join(part for part in (
            resource.get('module', ''),
            resource.get('type', ''),
            resource.get('name', ''),
        ) if part)
        if address not in ('module.vm.vsphere_virtual_machine.vm',
                           'vsphere_virtual_machine.jira_vm'):
            raise SafetyError(f'Unexpected managed VM resource in state: {address}')
        instances = resource.get('instances') or []
        if len(instances) != 1:
            raise SafetyError('Expected exactly one VM instance in per-VM state')
        attr = instances[0].get('attributes') or {}
        if attr.get('name') != expected_name or not attr.get('id'):
            raise SafetyError('VM identity does not match the requested name')
        candidates.append(address)

    if len(candidates) != 1:
        raise SafetyError(f'Expected exactly one managed VM, found {len(candidates)}')

    def is_data(resource: dict, name: str) -> bool:
        return (resource.get('mode') == 'data' and
                resource.get('type') == 'vsphere_virtual_machine' and
                resource.get('name') == name and
                not resource.get('module') and
                bool(resource.get('instances')))

    # Windows lookup is conditional; Debian template data may exist for both.
    if any(is_data(r, 'windows_template') for r in resources):
        os_name = 'Windows Server 2022'
    elif any(is_data(r, 'template') for r in resources):
        os_name = 'Debian 13'
    else:
        raise SafetyError('Unable to establish Windows/Debian template from state')
    return candidates[0], os_name


def main() -> int:
    if len(sys.argv) != 2:
        print('Usage: decommission-verify-state.py VM_NAME', file=sys.stderr)
        return 2
    try:
        state = json.loads(subprocess.check_output(
            ['terraform', 'state', 'pull'], text=True))
        address, os_name = verify_state(state, sys.argv[1])
    except (SafetyError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(f'ERROR: State identity/OS verification failed: {exc}', file=sys.stderr)
        return 1
    print(f'{address}\t{os_name}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
