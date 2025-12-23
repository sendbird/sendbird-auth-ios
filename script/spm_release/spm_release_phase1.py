#!/usr/bin/env python3
"""
SPM Release Phase 1: Build XCFramework and create Private repo PR.

This script performs:
1. Verify release branch and clean worktree
2. Verify GitHub auth
3. Build Dynamic and Static XCFrameworks
4. Compute checksums
5. Commit and push changes
6. Create Private repo PR

Output: release/release_state.json with version, checksums, and PR URL
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from release_common import (
    ROOT,
    compute_checksum,
    ensure_clean_worktree,
    ensure_github_auth,
    ensure_release_branch,
    load_pr_template,
    run_command,
    save_release_state,
)


def build_xcframework(project, build_static, build_mac):
    """Build XCFramework using build_xcframework.py."""
    args = ["python3", str(ROOT / "script" / "build_xcframework.py"), "-p", project]
    if build_static:
        args.append("--static")
    if build_mac:
        args.append("--mac")
    run_command(args)


def build_all_xcframeworks(project, build_mac):
    """Build both dynamic and static XCFrameworks."""
    print("[info] Building dynamic XCFramework...")
    build_xcframework(project, build_static=False, build_mac=build_mac)
    print("[info] Building static XCFramework...")
    build_xcframework(project, build_static=True, build_mac=build_mac)


def maybe_commit_and_push(branch, version):
    """Commit and push changes if any exist."""
    status = run_command(["git", "status", "--porcelain"], capture_output=True)
    if not status:
        print("[info] No changes to commit. Skipping commit step.")
        return False

    run_command(["git", "add", "."])
    run_command(["git", "commit", "-m", f"Release {version}"])
    run_command(["git", "push", "origin", branch])
    return True


def create_private_pr(private_repo, branch, version, checksum):
    """Create PR on private repo."""
    body = load_pr_template(version, checksum)
    return run_command(
        [
            "gh",
            "pr",
            "create",
            "--repo",
            private_repo,
            "--base",
            "main",
            "--head",
            branch,
            "--title",
            f"Release {version}",
            "--body",
            body,
        ],
        capture_output=True,
    )


def parse_args():
    parser = argparse.ArgumentParser(description="SPM Release Phase 1: Build and create Private PR.")
    parser.add_argument("--project", default="SendbirdAuthSDK")
    parser.add_argument("--mac", action="store_true", help="Include macOS build.")
    parser.add_argument("--private-repo", default="sendbird/auth-ios")
    parser.add_argument("--public-repo", default="sendbird/sendbird-auth-ios")
    return parser.parse_args()


def main():
    args = parse_args()
    project = args.project
    zip_path_dynamic = ROOT / "release" / f"{project}.xcframework.zip"
    zip_path_static = ROOT / "release" / f"{project}Static.xcframework.zip"

    try:
        branch, version = ensure_release_branch()
        ensure_clean_worktree()
        ensure_github_auth(args.private_repo, args.public_repo)

        print(f"[info] Phase 1: Releasing version {version} on branch {branch}")

        # Build XCFrameworks
        build_all_xcframeworks(project, args.mac)

        # Compute checksums
        checksum_dynamic = compute_checksum(zip_path_dynamic)
        checksum_static = compute_checksum(zip_path_static)
        print(f"[info] Checksum (dynamic): {checksum_dynamic}")
        print(f"[info] Checksum (static):  {checksum_static}")

        # Commit and push
        changes_committed = maybe_commit_and_push(branch, version)
        if changes_committed:
            print("[info] Commit and push completed.")

        # Create Private PR
        private_pr_url = create_private_pr(args.private_repo, branch, version, checksum_dynamic)
        print(f"[info] Private repo PR created: {private_pr_url}")

        # Save state for next phases
        save_release_state({
            "version": version,
            "branch": branch,
            "project": project,
            "checksum_dynamic": checksum_dynamic,
            "checksum_static": checksum_static,
            "private_pr_url": private_pr_url,
            "private_repo": args.private_repo,
            "public_repo": args.public_repo,
        })

        print("[done] Phase 1 complete. Merge the Private PR, then run phase2.")
        print(f"       PR: {private_pr_url}")

    except Exception as exc:
        print(f"[error] {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
