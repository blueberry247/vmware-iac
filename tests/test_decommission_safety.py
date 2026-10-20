"""Offline, non-destructive tests of decommission safeguards."""
import importlib.util
from pathlib import Path
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'


def load(filename):
    spec = importlib.util.spec_from_file_location(filename.replace('-', '_'), SCRIPTS / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


state = load('decommission-verify-state.py')
plan = load('decommission-validate-plan.py')


def sample_state(name='TF-VM-025', windows=False, module=True):
    vm = {'mode': 'managed', 'type': 'vsphere_virtual_machine',
          'name': 'vm' if module else 'jira_vm',
          'instances': [{'attributes': {'name': name, 'id': 'vm-uuid'}}]}
    if module:
        vm['module'] = 'module.vm'
    template = {'mode': 'data', 'type': 'vsphere_virtual_machine',
                'name': 'template', 'instances': [{'attributes': {'name': 'Debian'}}]}
    resources = [vm, template]
    if windows:
        resources.append({'mode': 'data', 'type': 'vsphere_virtual_machine',
                          'name': 'windows_template', 'instances': [{'attributes': {}}]})
    return {'resources': resources}


def sample_plan(name='TF-VM-025', address='module.vm.vsphere_virtual_machine.vm'):
    return {'resource_changes': [{'mode': 'managed', 'type': 'vsphere_virtual_machine',
                                  'address': address, 'change': {'actions': ['delete'],
                                   'before': {'name': name, 'id': 'vm-uuid'}, 'after': None}}]}


class TestDecommissionSafety(unittest.TestCase):
    def test_module_debian(self):
        self.assertEqual(state.verify_state(sample_state(), 'TF-VM-025'),
                         ('module.vm.vsphere_virtual_machine.vm', 'Debian 13'))

    def test_windows_preferred_if_default_debian_lookup_exists(self):
        self.assertEqual(state.verify_state(sample_state(windows=True), 'TF-VM-025')[1],
                         'Windows Server 2022')

    def test_legacy_state(self):
        self.assertEqual(state.verify_state(sample_state(module=False), 'TF-VM-025')[0],
                         'vsphere_virtual_machine.jira_vm')

    def test_wrong_vm_state(self):
        with self.assertRaises(state.SafetyError):
            state.verify_state(sample_state(), 'TF-VM-999')

    def test_missing_os_template(self):
        document = sample_state()
        document['resources'] = document['resources'][:1]
        with self.assertRaises(state.SafetyError):
            state.verify_state(document, 'TF-VM-025')

    def test_additional_vm_in_state(self):
        document = sample_state()
        document['resources'].append(sample_state(name='TF-VM-026')['resources'][0])
        with self.assertRaises(state.SafetyError):
            state.verify_state(document, 'TF-VM-025')

    def test_exactly_one_vm_delete(self):
        plan.validate_destroy_plan(sample_plan(), 'module.vm.vsphere_virtual_machine.vm', 'TF-VM-025')

    def test_other_vm_blocked(self):
        with self.assertRaises(plan.SafetyError):
            plan.validate_destroy_plan(sample_plan(name='TF-VM-026'),
                                       'module.vm.vsphere_virtual_machine.vm', 'TF-VM-025')

    def test_replacement_blocked(self):
        document = sample_plan()
        document['resource_changes'][0]['change']['actions'] = ['delete', 'create']
        with self.assertRaises(plan.SafetyError):
            plan.validate_destroy_plan(document, 'module.vm.vsphere_virtual_machine.vm', 'TF-VM-025')

    def test_extra_resource_blocked(self):
        document = sample_plan()
        document['resource_changes'].append(sample_plan()['resource_changes'][0])
        with self.assertRaises(plan.SafetyError):
            plan.validate_destroy_plan(document, 'module.vm.vsphere_virtual_machine.vm', 'TF-VM-025')

    def test_no_deletion_blocked(self):
        with self.assertRaises(plan.SafetyError):
            plan.validate_destroy_plan({'resource_changes': []},
                                       'module.vm.vsphere_virtual_machine.vm', 'TF-VM-025')


if __name__ == '__main__':
    unittest.main()
