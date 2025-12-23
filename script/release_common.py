#!/usr/bin/env python3
"""
Common utilities for release scripts.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PR_TEMPLATE_PATH = ROOT / ".claude" / "spm-release" / "PR_TEMPLATE.md"
RELEASE_STATE_PATH = ROOT / "release" / "release_state.json"


def run_command(command, *, cwd=None, capture_output=False):
    """Run a command and return stdout when requested."""
    print(f"[cmd] {' '.join(command)}")
    result = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=capture_output,
    )
    if result.returncode != 0:
        if capture_output:
            sys.stderr.write(result.stdout or "")
            sys.stderr.write(result.stderr or "")
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(command)}")
    return result.stdout.strip() if capture_output else None


def ensure_release_branch():
    """Verify current branch is release/X.X.X and return (branch, version)."""
    branch = run_command(["git", "branch", "--show-current"], capture_output=True)
    match = re.match(r"^release/([0-9]+\.[0-9]+\.[0-9]+)$", branch or "")
    if not match:
        raise RuntimeError(f"Current branch must be release/X.X.X. Found: {branch}")
    return branch, match.group(1)


def ensure_clean_worktree():
    """Verify working directory is clean."""
    status = run_command(["git", "status", "--porcelain"], capture_output=True)
    if status:
        raise RuntimeError("Working directory is not clean. Commit or stash changes first.")


def ensure_github_auth(private_repo, public_repo):
    """Verify GitHub CLI auth and repo permissions."""
    run_command(["gh", "auth", "status"])
    for repo in (private_repo, public_repo):
        permission = run_command(
            ["gh", "repo", "view", repo, "--json", "viewerPermission", "--jq", ".viewerPermission"],
            capture_output=True,
        )
        if permission not in {"ADMIN", "WRITE", "MAINTAIN"}:
            raise RuntimeError(f"Need WRITE permission for {repo}. Current: {permission}")


def check_pr_merged(pr_url):
    """Check if PR is actually merged."""
    result = run_command(
        ["gh", "pr", "view", pr_url, "--json", "merged"],
        capture_output=True,
    )
    data = json.loads(result)
    return data.get("merged", False)


def compute_checksum(zip_path):
    """Compute Swift package checksum for a zip file."""
    if not zip_path.exists():
        raise RuntimeError(f"XCFramework zip not found: {zip_path}")
    checksum = run_command(
        ["swift", "package", "compute-checksum", str(zip_path)],
        capture_output=True,
    )
    return checksum


def load_release_state():
    """Load release state from JSON file."""
    if not RELEASE_STATE_PATH.exists():
        raise RuntimeError(f"Release state not found: {RELEASE_STATE_PATH}. Run phase1 first.")
    return json.loads(RELEASE_STATE_PATH.read_text())


def save_release_state(state):
    """Save release state to JSON file."""
    RELEASE_STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    RELEASE_STATE_PATH.write_text(json.dumps(state, indent=2) + "\n")
    print(f"[info] Release state saved to {RELEASE_STATE_PATH}")


def load_pr_template(version, checksum):
    """Load and render PR template."""
    if not PR_TEMPLATE_PATH.exists():
        raise RuntimeError(f"PR template not found: {PR_TEMPLATE_PATH}")
    body = PR_TEMPLATE_PATH.read_text()
    body = body.replace("${VERSION}", version).replace("${CHECKSUM}", checksum)
    return body
