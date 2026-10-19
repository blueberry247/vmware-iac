#!/usr/bin/env python3
"""Jira Cloud preflight and completion for the VMware resize pipeline.

preflight: verify the issue is not Done and has ONE Resolved transition.
complete: after successful Terraform apply, atomically add comment + transition.
If completion fails, retry Jira only; DO NOT rerun Terraform apply.
"""
import base64
import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import Request, urlopen


class JiraError(RuntimeError):
    pass


class JiraClient:
    def __init__(self):
        self.base = os.environ.get("JIRA_BASE_URL", "").strip().rstrip("/")
        self.issue = os.environ.get("JIRA_ISSUE_KEY", "").strip().upper()
        email = os.environ.get("JIRA_EMAIL", "").strip()
        token = os.environ.get("JIRA_API_TOKEN", "")
        parsed = urlsplit(self.base)
        if (parsed.scheme != "https" or not parsed.netloc or parsed.path or
                parsed.query or parsed.fragment or not email or not token):
            raise JiraError("Invalid Jira site URL or missing Jira credentials")
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*-[0-9]+", self.issue):
            raise JiraError("Invalid Jira issue key")
        basic = base64.b64encode(f"{email}:{token}".encode()).decode()
        self.headers = {
            "Authorization": "Basic " + basic,
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        self.path = "/rest/api/3/issue/" + quote(self.issue, safe="")

    def request(self, method, path, payload=None):
        body = json.dumps(payload).encode("utf-8") if payload is not None else None
        try:
            req = Request(self.base + path, headers=self.headers, data=body, method=method)
            with urlopen(req, timeout=30) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except HTTPError as exc:
            raise JiraError(f"Jira returned HTTP {exc.code} for {method}; check workflow/permissions") from exc
        except (URLError, TimeoutError) as exc:
            raise JiraError(f"Jira connection failed ({type(exc).__name__})") from exc
        except json.JSONDecodeError as exc:
            raise JiraError("Jira returned invalid JSON") from exc

    def status(self):
        info = (self.request("GET", self.path + "?fields=status")
                .get("fields", {}).get("status") or {})
        name = info.get("name", "")
        category = ((info.get("statusCategory") or {}).get("key") or "").casefold()
        return name, category

    def resolved_transition(self):
        transitions = self.request("GET", self.path + "/transitions").get("transitions") or []
        matches = [t for t in transitions
                   if ((t.get("to") or {}).get("name") or "").casefold() == "resolved"]
        if len(matches) != 1:
            raise JiraError(f"Expected exactly one available Resolved transition; found {len(matches)}")
        return matches[0]["id"]


def is_done(status, category):
    return category == "done" or status.casefold() in {"resolved", "closed", "done"}


def preflight(client):
    name, category = client.status()
    if is_done(name, category):
        raise JiraError(f"{client.issue} already completed ({name}); resize refused")
    client.resolved_transition()
    print(f"Jira preflight passed: {client.issue}, status {name}; Resolved transition available")


def complete(client):
    name, category = client.status()
    if is_done(name, category):
        print(f"{client.issue} already completed ({name}); no duplicate comment")
        return
    transition_id = client.resolved_transition()
    try:
        vm_name = os.environ["VM_NAME"]
        cpu = int(os.environ["REQUESTED_CPU"])
        memory = int(os.environ["REQUESTED_MEMORY"])
        build_id = os.environ["BUILD_ID"]
    except (KeyError, ValueError) as exc:
        raise JiraError("Missing/invalid resize metadata for Jira completion") from exc
    message = (
        "VM RESIZE COMPLETED SUCCESSFULLY\n"
        f"Jira ticket: {client.issue}\n"
        f"VM: {vm_name}\n"
        f"CPU: {cpu} vCPU\n"
        f"Memory: {memory} MB\n"
        "Terraform apply succeeded; 0 VMs created/deleted.\n"
        "Validated plan allowed only CPU and RAM changes; "
        "no datastore/disk/network changes planned.\n"
        f"Azure DevOps build: {build_id}\n"
        "Note: power-on continuity and guest OS health are not verified by Jira callback."
    )
    adf = {
        "type": "doc", "version": 1,
        "content": [{"type": "paragraph", "content": [{"type": "text", "text": line}]}
                    for line in message.split("\n")],
    }
    # Atomic Jira transition + comment, as in the original pipeline.
    client.request("POST", client.path + "/transitions", {
        "transition": {"id": transition_id},
        "update": {"comment": [{"add": {"body": adf}}]},
    })
    new_name, new_category = client.status()
    if new_name.casefold() != "resolved" or new_category != "done":
        raise JiraError(f"Transition returned, but issue status is {new_name!r} ({new_category!r})")
    print(f"Jira {client.issue}: success comment added and issue moved to Resolved")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in {"preflight", "complete"}:
        sys.exit("Usage: jira.py preflight|complete")
    try:
        client = JiraClient()
        if sys.argv[1] == "preflight":
            preflight(client)
        else:
            complete(client)
    except JiraError as exc:
        sys.exit(f"JIRA {sys.argv[1].upper()} FAILED: {exc}")


if __name__ == "__main__":
    main()
