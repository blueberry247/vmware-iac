"""Offline unit tests. Run: python -m unittest discover -s tests -v"""
import importlib.util
import pathlib
import unittest

SCRIPTS = pathlib.Path(__file__).resolve().parent.parent / "scripts"


def load(module, filename):
    spec = importlib.util.spec_from_file_location(module, SCRIPTS / filename)
    target = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(target)
    return target


validator = load("validator", "validate-resize-plan.py")
discovery = load("discovery", "discover-datastore.py")


def make_plan(before=None, after=None, actions=None):
    old = {"name": "TF-VM-013", "id": "uuid1", "datastore_id": "datastore-22",
           "num_cpus": 4, "memory": 4096}
    new = dict(old)
    new["num_cpus"] = 6
    if before:
        old.update(before)
    if after:
        new.update(after)
    return {"resource_changes": [{"address": validator.TARGET, "mode": "managed",
                                  "change": {"actions": actions or ["update"],
                                             "before": old, "after": new,
                                             "after_unknown": {}}}]}


class PlanSafetyTests(unittest.TestCase):
    def check(self, plan):
        return validator.validate(plan, "TF-VM-013", 6, 4096, "datastore-22")

    def test_cpu_only_allowed(self):
        self.check(make_plan())

    def test_datastore_move_rejected(self):
        with self.assertRaisesRegex(ValueError, "Datastore"):
            self.check(make_plan(after={"datastore_id": "datastore-1140"}))

    def test_rename_rejected(self):
        with self.assertRaisesRegex(ValueError, "VM name"):
            self.check(make_plan(after={"name": "TF-VM-999"}))

    def test_destroy_rejected(self):
        with self.assertRaisesRegex(ValueError, "in place"):
            self.check(make_plan(actions=["delete"]))

    def test_other_vm_rejected(self):
        plan = make_plan()
        plan["resource_changes"][0]["address"] = "module.vm.vsphere_virtual_machine.other"
        with self.assertRaisesRegex(ValueError, "Unexpected managed resource"):
            self.check(plan)

    def test_unexpected_setting_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unexpected VM setting"):
            self.check(make_plan(after={"network_interface": []}))

    def test_computed_unknown_rejected(self):
        plan = make_plan()
        plan["resource_changes"][0]["change"]["after_unknown"] = {"datastore_id": True}
        with self.assertRaisesRegex(ValueError, "unknown planned value"):
            self.check(plan)

    def test_no_change_rejected(self):
        with self.assertRaisesRegex(ValueError, "exactly one"):
            self.check({"resource_changes": []})

    def test_extra_update_rejected(self):
        plan = make_plan()
        plan["resource_changes"].append({"address": "random.resource", "mode": "managed",
                                          "change": {"actions": ["create"]}})
        with self.assertRaisesRegex(ValueError, "Unexpected managed resource"):
            self.check(plan)


class DatastoreTests(unittest.TestCase):
    def test_refresh_drift_wins(self):
        doc = {"resource_drift": [{"address": discovery.TARGET, "mode": "managed",
                                   "change": {"actions": ["update"],
                                              "before": {"id": "uuid1", "datastore_id": "datastore-1140"},
                                              "after": {"id": "uuid1", "name": "TF-VM-013",
                                                        "datastore_id": "datastore-22"}}}]}
        result, _ = discovery.datastore_from_document(doc, "TF-VM-013")
        self.assertEqual(result, "datastore-22")

    def test_invalid_name_rejected(self):
        doc = {"resource_drift": [{"address": discovery.TARGET, "mode": "managed",
                                   "change": {"actions": ["update"],
                                              "after": {"id": "uuid1", "name": "TF-VM-999",
                                                        "datastore_id": "datastore-22"}}}]}
        with self.assertRaisesRegex(ValueError, "identity"):
            discovery.datastore_from_document(doc, "TF-VM-013")


if __name__ == "__main__":
    unittest.main()
