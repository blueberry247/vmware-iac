"""Offline Jira transition tests: no network access or Jira credentials needed."""
import importlib.util
import io
import json
import os
from pathlib import Path
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'provision-jira-resolve.py'
spec = importlib.util.spec_from_file_location('provision_jira_resolve', SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def issue(status, category, resolution=None):
    return {'fields': {'status': {'name': status, 'statusCategory': {'key': category}},
                       'resolution': {'name': resolution} if resolution else None}}


def transition(to_name='Resolved', to_category='done', name='Resolve Issue', id='41'):
    return {'id': id, 'name': name, 'to': {'name': to_name, 'statusCategory': {'key': to_category}}}


class FakeResponse:
    def __init__(self, value):
        self.value = value

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def read(self):
        return json.dumps(self.value).encode('utf-8')


class JiraResolveTests(unittest.TestCase):
    def test_choose_only_named_done_status(self):
        transitions = [
            transition('Cancelled', 'done', 'Cancel', '10'),
            transition('Resolved', 'indeterminate', 'Misconfigured status', '20'),
            transition('Resolved', 'done', 'Resolve Issue', '41'),
        ]
        self.assertEqual(mod.choose_transition(transitions, 'Resolved'), '41')

    def test_refuses_other_statuses(self):
        with self.assertRaisesRegex(RuntimeError, 'Cannot safely resolve'):
            mod.choose_transition([transition('Cancelled', 'done')], 'Resolved')

    def test_refuses_multiple_ambiguous_transitions(self):
        with self.assertRaisesRegex(RuntimeError, 'expected exactly one transition'):
            mod.choose_transition([transition(id='41'), transition(id='42')], 'Resolved')

    def test_refuses_non_numeric_transition_ids(self):
        with self.assertRaisesRegex(RuntimeError, 'Cannot safely resolve'):
            mod.choose_transition([transition(id='something unsafe')], 'Resolved')

    def test_resolve_posts_transition_and_verifies_resolution(self):
        replies = [
            issue('Waiting for support', 'indeterminate'),
            {'transitions': [transition()]},
            {},
            issue('Resolved', 'done', resolution='Done'),
        ]
        requests = []

        def fake_open(req, timeout=30):
            requests.append(req)
            return FakeResponse(replies[len(requests) - 1])

        with patch.dict(os.environ, {
            'JIRA_BASE_URL': 'https://example.atlassian.net',
            'JIRA_EMAIL': 'jira@example.test',
            'JIRA_API_TOKEN': 'PLACEHOLDER_SECRET',
            'JIRA_ISSUE_KEY': 'IT-43',
        }, clear=True), patch.object(mod.urllib.request, 'urlopen', fake_open):
            self.assertEqual(mod.main(), 0)
        self.assertEqual([r.get_method() for r in requests], ['GET', 'GET', 'POST', 'GET'])
        self.assertEqual(json.loads(requests[2].data), {'transition': {'id': '41'}})
        self.assertEqual(requests[0].full_url, 'https://example.atlassian.net/rest/api/3/issue/IT-43?fields=status,resolution')
        self.assertEqual(requests[2].full_url, 'https://example.atlassian.net/rest/api/3/issue/IT-43/transitions')

    def test_already_resolved_is_idempotent(self):
        requests = []
        def fake_open(req, timeout=30):
            requests.append(req)
            return FakeResponse(issue('Resolved', 'done', resolution='Done'))
        with patch.dict(os.environ, {
            'JIRA_BASE_URL': 'https://example.atlassian.net',
            'JIRA_EMAIL': 'jira@example.test',
            'JIRA_API_TOKEN': 'PLACEHOLDER_SECRET',
            'JIRA_ISSUE_KEY': 'IT-43',
        }, clear=True), patch.object(mod.urllib.request, 'urlopen', fake_open):
            self.assertEqual(mod.main(), 0)
        self.assertEqual(len(requests), 1)

    def test_does_not_overwrite_cancelled_ticket(self):
        with patch.dict(os.environ, {
            'JIRA_BASE_URL': 'https://example.atlassian.net',
            'JIRA_EMAIL': 'jira@example.test',
            'JIRA_API_TOKEN': 'PLACEHOLDER_SECRET',
            'JIRA_ISSUE_KEY': 'IT-43',
        }, clear=True), patch.object(mod.urllib.request, 'urlopen', return_value=FakeResponse(issue('Cancelled', 'done', 'Won\'t Do'))):
            with self.assertRaisesRegex(RuntimeError, 'terminal status'):
                mod.main()

    def test_resolution_is_required(self):
        replies = [issue('Waiting for support', 'indeterminate'), {'transitions': [transition()]}, {}, issue('Resolved', 'done')]
        with patch.dict(os.environ, {
            'JIRA_BASE_URL': 'https://example.atlassian.net',
            'JIRA_EMAIL': 'jira@example.test',
            'JIRA_API_TOKEN': 'PLACEHOLDER_SECRET',
            'JIRA_ISSUE_KEY': 'IT-43',
        }, clear=True), patch.object(mod.urllib.request, 'urlopen', side_effect=[FakeResponse(x) for x in replies]):
            with self.assertRaisesRegex(RuntimeError, 'Resolution field'):
                mod.main()


if __name__ == '__main__':
    unittest.main()
