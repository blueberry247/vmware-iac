#!/usr/bin/env python3
"""Fail closed unless a Terraform plan deletes exactly one expected VMware VM."""
import json
import subprocess
import sys


class SafetyError(ValueError):
    pass


def validate_destroy_plan(plan: dict, expected_address: str, expected_name: str) -> None:
    changes = [r for r in plan.get('resource_changes', [])
               if r.get('mode') == 'managed'
               and (r.get('change') or {}).get('actions') != ['no-op']]
    if len(changes) != 1:
        raise SafetyError(f'Expected exactly one managed resource change, got {len(changes)}')
    resource = changes[0]
    change = resource.get('change') or {}
    old = change.get('before') or {}
    if (resource.get('address') != expected_address or
        resource.get('type') != 'vsphere_virtual_machine' or
        change.get('actions') != ['delete'] or
        old.get('name') != expected_name or
        not old.get('id')):
        raise SafetyError('Destroy plan does not delete only the requested VM')


def main() -> int:
    if len(sys.argv) != 4:
        print('Usage: decommission-validate-plan.py PLAN RESOURCE_ADDRESS VM_NAME', file=sys.stderr)
        return 2
    _, plan_path, address, vm_name = sys.argv
    try:
        plan = json.loads(subprocess.check_output(
            ['terraform', 'show', '-json', plan_path], text=True))
        validate_destroy_plan(plan, address, vm_name)
    except (SafetyError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(f'ERROR: Destroy safety validation failed: {exc}', file=sys.stderr)
        return 1
    print(f'SAFETY CHECK PASSED: exactly one deletion of {vm_name} ({address}).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
