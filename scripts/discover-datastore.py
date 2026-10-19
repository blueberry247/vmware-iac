#!/usr/bin/env python3
"""Read live VM datastore from a Terraform *refresh-only* plan JSON.

Output exactly the datastore ID on stdout; diagnostics on stderr.  An exact
managed resource, VM ID, and VM name are required.  Never read only an old
terraform state show value when vSphere reports drift.
"""
import json
import os
import re
import sys

TARGET = "module.vm.vsphere_virtual_machine.vm"


def fail(message):
    raise ValueError(message)


def find_resources(state_values):
    def walk(module):
        for item in module.get("resources", []):
            yield item
        for child in module.get("child_modules", []):
            yield from walk(child)

    root = (state_values or {}).get("root_module") or {}
    return [r for r in walk(root)
            if r.get("address") == TARGET and r.get("mode") == "managed"]


def datastore_from_document(document, expected_name):
    drift = [r for r in document.get("resource_drift", [])
             if r.get("address") == TARGET and r.get("mode") == "managed"]
    if len(drift) > 1:
        fail("Multiple drift records for the target VM")
    if drift:
        change = drift[0].get("change") or {}
        if change.get("actions") not in (["update"], ["no-op"]):
            fail("VM was replaced/deleted outside Terraform")
        values = change.get("after") or {}
        before = change.get("before") or {}
        if before.get("id") and before["id"] != values.get("id"):
            fail("VM UUID changed during refresh")
        source = "vSphere refresh resource_drift"
    else:
        matches = find_resources(document.get("planned_values"))
        source = "refresh-only planned_values"
        if not matches:
            matches = find_resources((document.get("prior_state") or {}).get("values"))
            source = "prior_state (no VM drift)"
        if len(matches) != 1:
            fail("Cannot uniquely identify VM in refreshed Terraform plan")
        values = matches[0].get("values") or {}

    if values.get("name") != expected_name or not values.get("id"):
        fail("Refreshed VM identity does not match Jira request")
    datastore = values.get("datastore_id")
    if not isinstance(datastore, str) or not re.fullmatch(r"datastore-[0-9]+", datastore):
        fail("Refresh returned invalid datastore ID")
    return datastore, source


def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: discover-datastore.py <refresh-only-plan.json>")
    expected_name = os.environ.get("TF_VAR_vm_name", "")
    if not expected_name:
        sys.exit("ERROR: TF_VAR_vm_name is required")
    try:
        with open(sys.argv[1], encoding="utf-8") as handle:
            datastore, source = datastore_from_document(json.load(handle), expected_name)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        sys.exit(f"ERROR: {exc}")
    print(f"Datastore source: {source}", file=sys.stderr)
    print(datastore)


if __name__ == "__main__":
    main()
