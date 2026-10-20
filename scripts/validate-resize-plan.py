#!/usr/bin/env python3
"""Fail-closed guard for a VMware CPU/RAM-only Terraform plan.

Only ONE in-place update of the exact target VM is permitted. Any managed
resource addition, deletion, VM replacement, datastore change, or unknown
non-resize attribute is rejected. Uses Terraform show -json output.
"""
import json
import os
import sys

TARGET = "module.vm.vsphere_virtual_machine.vm"
ALLOWED = {"num_cpus", "memory"}


def fail(message):
    raise ValueError(message)


def validate(plan, vm_name, cpu, memory, datastore):
    updates = []
    for resource in plan.get("resource_changes", []):
        if resource.get("mode") != "managed":
            continue
        address = resource.get("address", "<unknown>")
        change = resource.get("change") or {}
        actions = change.get("actions", [])
        if actions == ["no-op"]:
            continue
        if address != TARGET:
            fail(f"Unexpected managed resource change: {address}")
        if actions != ["update"]:
            fail(f"VM must be updated in place, not replaced/deleted: {actions}")
        before = change.get("before") or {}
        after = change.get("after") or {}
        if before.get("name") != vm_name or after.get("name") != vm_name:
            fail("VM name does not match Jira request")
        if before.get("datastore_id") != datastore or after.get("datastore_id") != datastore:
            fail("Datastore differs from live vSphere datastore")
        changed = {key for key in set(before) | set(after)
                   if before.get(key) != after.get(key)}
        if not changed:
            fail("No actual VM setting changes found")
        if changed - ALLOWED:
            fail(f"Unexpected VM setting changes: {sorted(changed - ALLOWED)}")
        unknown = change.get("after_unknown") or {}
        for key, value in unknown.items():
            if key not in ALLOWED and value:
                fail(f"Non-resize attribute has unknown planned value: {key}")
        if after.get("num_cpus") != cpu:
            fail("CPU does not match Jira request")
        if after.get("memory") != memory:
            fail("RAM does not match Jira request")
        updates.append((before, after))
    if len(updates) != 1:
        fail(f"Expected exactly one VM update, found {len(updates)}")
    return updates[0]


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: validate-resize-plan.py <resize-plan.json>")
    try:
        vm_name = os.environ["TF_VAR_vm_name"]
        cpu = int(os.environ["TF_VAR_vm_cpu"])
        memory = int(os.environ["TF_VAR_vm_memory"])
        datastore = os.environ["TF_VAR_vm_datastore_id"]
        with open(sys.argv[1], encoding="utf-8") as handle:
            before, after = validate(json.load(handle), vm_name, cpu, memory, datastore)
    except (KeyError, OSError, json.JSONDecodeError, ValueError) as exc:
        sys.exit(f"RESIZE BLOCKED: {exc}")
    print("SAFETY CHECK PASSED: only permitted CPU/RAM changes")
    print(f"VM: {vm_name}")
    print(f"CPU: {before.get('num_cpus')} -> {after.get('num_cpus')}")
    print(f"Memory (MB): {before.get('memory')} -> {after.get('memory')}")


if __name__ == "__main__":
    main()
