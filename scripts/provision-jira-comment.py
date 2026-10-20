#!/usr/bin/env python3
"""Post the same Jira success comment as the original provisioning pipeline.

No workflow/status transition is performed here; that can be added in a separate PR.
"""
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def build_comment(vm_name: str, hostname: str, vm_ip: str) -> dict:
    """Jira Cloud API v3 expects an Atlassian Document Format body."""
    lines = [
        'VM provisioning completed successfully.',
        f'VM Name: {vm_name}',
        f'Hostname: {hostname}',
        f'IP Address: {vm_ip}',
        'Provisioned automatically by Azure DevOps / Terraform.',
    ]
    return {
        'body': {
            'type': 'doc', 'version': 1,
            'content': [
                {'type': 'paragraph', 'content': [{'type': 'text', 'text': line}]}
                for line in lines
            ],
        }
    }


def required(name: str) -> str:
    value = os.environ.get(name, '')
    if not value:
        raise ValueError(f'Missing required environment variable: {name}')
    return value


def main() -> int:
    base_url = required('JIRA_BASE_URL').rstrip('/')
    email = required('JIRA_EMAIL')
    token = required('JIRA_API_TOKEN')
    issue_key = required('JIRA_ISSUE_KEY')
    vm_name = required('VM_NAME_PARAMETER')
    hostname = required('VM_HOSTNAME')
    ip = required('PROVISIONED_VM_IP')

    print(f'Updating Jira issue: {issue_key}', flush=True)
    print(f'VM Name: {vm_name}\nVM IP: {ip}', flush=True)
    url = f'{base_url}/rest/api/3/issue/{urllib.parse.quote(issue_key, safe="")}/comment'
    auth = base64.b64encode(f'{email}:{token}'.encode('utf-8')).decode('ascii')
    request = urllib.request.Request(
        url,
        data=json.dumps(build_comment(vm_name, hostname, ip)).encode('utf-8'),
        method='POST',
        headers={
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': f'Basic {auth}',
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            if not 200 <= response.status < 300:
                raise RuntimeError(f'Jira comment returned HTTP {response.status}')
    except urllib.error.HTTPError as error:
        # The token is never printed. Jira's response can help diagnose permissions.
        details = error.read(2048).decode('utf-8', errors='replace')
        raise RuntimeError(f'Jira comment failed (HTTP {error.code}): {details}') from None

    print(f'Jira issue {issue_key} updated successfully.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, urllib.error.URLError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(1)
