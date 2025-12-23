#!/usr/bin/env python3
"""
SPM Release Phase 2: Tag, backmerge, and create Public repo PR.

This script performs (after Private PR is merged):
1. Create tag on main and push
2. Backmerge main into develop
3. Create Public repo PR with updated Package.swift

Input: release/release_state.json (from phase1)
Output: Updated release/release_state.json with public_pr_url
"""

import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from release_common import (
    ROOT,
    load_release_state,
    run_command,
    save_release_state,
)


def tag_and_backmerge(version, original_branch):
    """Create tag on main and backmerge to develop."""
    run_command(["git", "checkout", "main"])
    run_command(["git", "pull", "origin", "main"])
    run_command(["git", "tag", version])
    run_command(["git", "push", "origin", version])

    run_command(["git", "checkout", "develop"])
    run_command(["git", "pull", "origin", "develop"])
    run_command(["git", "merge", "main"])
    run_command(["git", "push", "origin", "develop"])

    run_command(["git", "checkout", original_branch])


def render_public_package(project, version, checksum_dynamic, checksum_static, public_repo):
    """Render Package.swift with both dynamic and static targets."""
    url_dynamic = f"https://github.com/{public_repo}/releases/download/{version}/{project}.xcframework.zip"
    url_static = f"https://github.com/{public_repo}/releases/download/{version}/{project}Static.xcframework.zip"
    return f'''// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "{project}",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "{project}",
            targets: ["{project}"]
        ),
        .library(
            name: "{project}Static",
            targets: ["{project}Static"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "{project}",
            url: "{url_dynamic}",
            checksum: "{checksum_dynamic}"
        ),
        .binaryTarget(
            name: "{project}Static",
            url: "{url_static}",
            checksum: "{checksum_static}"
        ),
    ]
)
'''


def create_public_pr(public_repo, version, checksum_dynamic, checksum_static, project):
    """Clone public repo, update Package.swift, create PR."""
    temp_dir = Path(tempfile.mkdtemp(prefix="sendbird-auth-ios-"))
    print(f"[info] Cloning public repo into {temp_dir}")
    try:
        run_command(["gh", "repo", "clone", public_repo, str(temp_dir)])
        run_command(["git", "checkout", "-b", f"release/{version}"], cwd=temp_dir)

        package_swift = render_public_package(project, version, checksum_dynamic, checksum_static, public_repo)
        (temp_dir / "Package.swift").write_text(package_swift)

        run_command(["git", "add", "Package.swift"], cwd=temp_dir)
        run_command(["git", "commit", "-m", f"Release {version}"], cwd=temp_dir)
        run_command(["git", "push", "origin", f"release/{version}"], cwd=temp_dir)

        pr_url = run_command(
            [
                "gh",
                "pr",
                "create",
                "--base",
                "main",
                "--head",
                f"release/{version}",
                "--title",
                f"Release {version}",
                "--body",
                f"Update Package.swift for version {version}",
            ],
            cwd=temp_dir,
            capture_output=True,
        )
        return pr_url
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def main():
    try:
        state = load_release_state()
        version = state["version"]
        branch = state["branch"]
        project = state["project"]
        checksum_dynamic = state["checksum_dynamic"]
        checksum_static = state["checksum_static"]
        public_repo = state["public_repo"]

        print(f"[info] Phase 2: Version {version}")

        # Tag and backmerge
        tag_and_backmerge(version, branch)
        print("[info] Tag created and backmerged into develop.")

        # Create Public PR
        public_pr_url = create_public_pr(
            public_repo, version, checksum_dynamic, checksum_static, project
        )
        print(f"[info] Public repo PR created: {public_pr_url}")

        # Update state
        state["public_pr_url"] = public_pr_url
        save_release_state(state)

        print("[done] Phase 2 complete. Merge the Public PR, then run phase3.")
        print(f"       PR: {public_pr_url}")

    except Exception as exc:
        print(f"[error] {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
