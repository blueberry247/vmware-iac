"""Small offline checks; run from the extracted package root."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ProvisioningRefactorTests(unittest.TestCase):
    def test_jira_document_format(self):
        spec = importlib.util.spec_from_file_location(
            'provision_jira_comment', ROOT / 'scripts/provision-jira-comment.py'
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        payload = module.build_comment('TF-VM-040', 'tf-vm-040', '192.168.1.237')
        self.assertEqual(payload['body']['type'], 'doc')
        paragraphs = [p['content'][0]['text'] for p in payload['body']['content']]
        self.assertEqual(paragraphs, [
            'VM provisioning completed successfully.',
            'VM Name: TF-VM-040',
            'Hostname: tf-vm-040',
            'IP Address: 192.168.1.237',
            'Provisioned automatically by Azure DevOps / Terraform.',
        ])

    def test_debian_stays_strict_about_host_keys(self):
        for filename in ('provision-register-debian-host-key.sh', 'provision-debian-ready.sh'):
            source = (ROOT / 'scripts' / filename).read_text()
            self.assertIn('StrictHostKeyChecking=yes', source)
        self.assertIn('flock -x', (ROOT / 'scripts/provision-register-debian-host-key.sh').read_text())

    def test_approved_encrypted_plan_still_used(self):
        plan = (ROOT / 'scripts/provision-plan.sh').read_text()
        apply = (ROOT / 'scripts/provision-apply.sh').read_text()
        self.assertIn('-detailed-exitcode', plan)
        self.assertIn('--cipher-algo AES256', plan)
        self.assertIn('tfplan.gpg', plan)
        self.assertIn('"$PLAN_ARTIFACT_FILE"', apply)
        self.assertIn('terraform apply', apply)
        self.assertIn('tfplan', apply)
        self.assertIn("'VMware-Production'", (ROOT / 'pipelines/provision-apply-stage.yml').read_text())

    def test_noop_path_preserved(self):
        data = (ROOT / 'pipelines/provision-postdeploy-stage.yml').read_text()
        self.assertIn("eq(dependencies.Apply.result, 'Skipped')", data)
        self.assertIn("eq(dependencies.Apply.result, 'Succeeded')", data)
        self.assertIn('TerraformPlan.terraformPlan.changesDetected', data)


if __name__ == '__main__':
    unittest.main()
