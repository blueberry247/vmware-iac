#!/usr/bin/env python3
"""Resolve the Jira provisioning issue only after the VM is ready and commented.

Never guess Jira transition IDs. Discover an available transition whose *target*
status is Resolved (or JIRA_RESOLVED_STATUS) and whose status category is done.
Fail loudly rather than silently leaving a successfully provisioned issue open.
"""
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request


def required(name: str) -> str:
    value = os.environ.get(name, '').strip()
    if not value:
        raise ValueError(f'Missing required environment variable: {name}')
    return value


def get_status(issue: dict) -> tuple[str, str, object]:
    fields = issue.get('fields', {})
    status = fields.get('status') or {}
    name = status.get('name') or ''
    category = (status.get('statusCategory') or {}).get('key') or ''
    return name, category.casefold(), fields.get('resolution')


def choose_transition(transitions: list, expected_status: str) -> str:
    """Return exactly one allowed transition ID to the expected done status."""
    matches = [t for t in transitions
               if (t.get('to') or {}).get('name', '').casefold() == expected_status.casefold()
               and ((t.get('to') or {}).get('statusCategory') or {}).get('key', '').casefold() == 'done']
    if len(matches) != 1 or not re.fullmatch(r'\d+', str(matches[0].get('id', ''))):
        available = ', '.join(sorted({
            f"{(t.get('to') or {}).get('name', '?')} ({t.get('name', '?')})" for t in transitions
        })) or 'none'
        raise RuntimeError(
            f'Cannot safely resolve Jira issue: expected exactly one transition to '
            f'"{expected_status}" (Done category). Available transitions: {available}. '
            'Check the Jira workflow or set JIRA_RESOLVED_STATUS to the correct status name.'
        )
    return str(matches[0]['id'])


def jira_request(base_url: str, auth: str, issue_key: str, suffix: str,
                 method: str = 'GET', payload: dict | None = None) -> dict:
    path = f'/rest/api/3/issue/{urllib.parse.quote(issue_key, safe="")}{suffix}'
    headers = {'Accept': 'application/json', 'Authorization': f'Basic {auth}'}
    data = None
    if payload is not None:
        headers['Content-Type'] = 'application/json'
        data = json.dumps(payload).encode('utf-8')
    request = urllib.request.Request(f'{base_url}{path}', data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            contents = response.read()
            return json.loads(contents) if contents else {}
    except urllib.error.HTTPError as error:
        # Do not log the request's Authorization header or the access token.
        raise RuntimeError(
            f'Jira {method} request failed with HTTP {error.code} ({suffix or "issue"}). '
            'Check Jira project permissions, available transitions, and required workflow fields.'
        ) from None


def main() -> int:
    base_url = required('JIRA_BASE_URL').rstrip('/')
    if not base_url.startswith('https://'):
        raise ValueError('JIRA_BASE_URL must use HTTPS')
    email = required('JIRA_EMAIL')
    token = required('JIRA_API_TOKEN')
    issue_key = required('JIRA_ISSUE_KEY')
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]*-[0-9]+', issue_key):
        raise ValueError('Invalid Jira issue key')
    target = os.environ.get('JIRA_RESOLVED_STATUS', 'Resolved').strip()
    if not target:
        raise ValueError('JIRA_RESOLVED_STATUS must not be empty')
    auth = base64.b64encode(f'{email}:{token}'.encode('utf-8')).decode('ascii')

    print(f'Checking Jira ticket {issue_key} before resolving it.', flush=True)
    fields = '?fields=status,resolution'
    issue = jira_request(base_url, auth, issue_key, fields)
    status_name, category, resolution = get_status(issue)

    if status_name.casefold() == target.casefold() and category == 'done':
        if resolution is None:
            raise RuntimeError(
                f'Jira ticket {issue_key} is in "{status_name}", but its resolution field '
                'is empty. Configure a Jira transition/post-function to set Resolution.'
            )
        print(f'Jira ticket {issue_key} is already resolved; no transition needed.')
        return 0

    if category == 'done':
        raise RuntimeError(
            f'Jira ticket {issue_key} is already in terminal status "{status_name}". '
            'Refusing to change a completed/cancelled request automatically.'
        )

    response = jira_request(base_url, auth, issue_key, '/transitions')
    transition_id = choose_transition(response.get('transitions', []), target)
    print(f'Transitioning Jira ticket {issue_key} from "{status_name}" to "{target}".')
    jira_request(base_url, auth, issue_key, '/transitions', method='POST',
                 payload={'transition': {'id': transition_id}})

    verified = jira_request(base_url, auth, issue_key, fields)
    new_name, new_category, new_resolution = get_status(verified)
    if new_name.casefold() != target.casefold() or new_category != 'done':
        raise RuntimeError(
            f'Jira transition returned but ticket {issue_key} status is "{new_name}" '
            f'(category "{new_category}"), not "{target}" (Done).'
        )
    if new_resolution is None:
        raise RuntimeError(
            f'Jira ticket {issue_key} moved to "{new_name}" but its Resolution field '
            'is still empty. Configure the Jira workflow transition to set Resolution.'
        )
    print(f'Jira ticket {issue_key} successfully resolved (Resolution: {new_resolution.get("name", "set")}).')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, urllib.error.URLError, json.JSONDecodeError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
