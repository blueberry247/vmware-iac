#!/usr/bin/env python3
"""Post a comment only after successful Terraform VM decommission."""
import base64
import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


def main() -> int:
    base = os.environ['JIRA_BASE_URL'].rstrip('/')
    email = os.environ['JIRA_EMAIL']
    token = os.environ['JIRA_API_TOKEN']
    issue = os.environ['JIRA_ISSUE_KEY'].upper()
    vm_name = os.environ['VM_NAME']
    if not base.startswith('https://') or not email or not token:
        sys.exit('JIRA COMMENT FAILED: Missing valid Jira configuration')
    if not re.fullmatch(r'[A-Z][A-Z0-9_]*-[0-9]+', issue):
        sys.exit('JIRA COMMENT FAILED: Invalid issue key')
    msg = (f'VM decommission completed successfully.\n'
           f'VM Name: {vm_name}\n'
           'The VM was removed by Azure DevOps / Terraform. '
           'Verify any external inventory or CMDB records separately.')
    doc = {'type': 'doc', 'version': 1, 'content': [
        {'type': 'paragraph', 'content': [{'type': 'text', 'text': line}]}
        for line in msg.split('\n')
    ]}
    auth = base64.b64encode(f'{email}:{token}'.encode()).decode()
    req = Request(
        f'{base}/rest/api/3/issue/{quote(issue, safe="")}/comment',
        data=json.dumps({'body': doc}).encode(),
        headers={'Authorization': f'Basic {auth}',
                 'Accept': 'application/json', 'Content-Type': 'application/json'},
        method='POST',
    )
    try:
        with urlopen(req, timeout=30) as response:
            if response.status not in (200, 201):
                raise RuntimeError(f'Unexpected Jira HTTP {response.status}')
    except (HTTPError, URLError, TimeoutError) as exc:
        sys.exit(f'JIRA COMMENT FAILED (VM may already be deleted): {exc}')
    print(f'Jira {issue}: decommission success comment added.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
