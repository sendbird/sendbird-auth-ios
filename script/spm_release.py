#!/usr/bin/env python3
"""
Automate the SendbirdAuthSDK SPM-only release flow described in
.claude/spm-release/SKILL.md.

Default mode runs the full release flow. Use --mode test to stop after
build + checksum (Step 1-2).
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PR_TEMPLATE_PATH = ROOT / ".claude" / "spm-release" / "PR_TEMPLATE.md"


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
            sys.stderr.write(result.stdout)
            sys.stderr.write(result.stderr)
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(command)}")
    return result.stdout.strip() if capture_output else None


def ensure_release_branch():
    branch = run_command(["git", "branch", "--show-current"], capture_output=True)
    match = re.match(r"^release/([0-9]+\.[0-9]+\.[0-9]+)$", branch or "")
    if not match:
        raise RuntimeError(f"Current branch must be release/X.X.X. Found: {branch}")
    return branch, match.group(1)


def ensure_clean_worktree():
    status = run_command(["git", "status", "--porcelain"], capture_output=True)
    if status:
        raise RuntimeError("Working directory is not clean. Commit or stash changes first.")


def ensure_github_auth(private_repo, public_repo):
    run_command(["gh", "auth", "status"])
    for repo in (private_repo, public_repo):
        permission = run_command(
            ["gh", "repo", "view", repo, "--json", "viewerPermission", "--jq", ".viewerPermission"],
            capture_output=True,
        )
        if permission not in {"ADMIN", "WRITE", "MAINTAIN"}:
            raise RuntimeError(f"Need WRITE permission for {repo}. Current: {permission}")


def build_xcframework(project, build_static, build_mac):
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


def compute_checksum(zip_path):
    if not zip_path.exists():
        raise RuntimeError(f"XCFramework zip not found: {zip_path}")
    checksum = run_command(
        ["swift", "package", "compute-checksum", str(zip_path)],
        capture_output=True,
    )
    return checksum


def maybe_commit_and_push(branch, version):
    status = run_command(["git", "status", "--porcelain"], capture_output=True)
    if not status:
        print("[info] No changes to commit. Skipping Step 3.")
        return False

    run_command(["git", "add", "."])
    run_command(["git", "commit", "-m", f"Release {version}"])
    run_command(["git", "push", "origin", branch])
    return True


def load_pr_template(version, checksum):
    if not PR_TEMPLATE_PATH.exists():
        raise RuntimeError(f"PR template not found: {PR_TEMPLATE_PATH}")
    body = PR_TEMPLATE_PATH.read_text()
    body = body.replace("${VERSION}", version).replace("${CHECKSUM}", checksum)
    return body


def create_private_pr(private_repo, branch, version, checksum):
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


def tag_and_backmerge(version, original_branch):
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
    return f"""// swift-tools-version:5.9

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
"""


def create_public_pr(public_repo, version, checksum_dynamic, checksum_static, project):
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


def check_pr_merged(pr_url):
    """Check if PR is actually merged."""
    result = run_command(
        ["gh", "pr", "view", pr_url, "--json", "merged"],
        capture_output=True,
    )
    data = json.loads(result)
    return data.get("merged", False)


def wait_for_pr_merge(pr_url, label):
    """Wait for user confirmation and verify PR is actually merged."""
    while True:
        answer = input(f"{label} (y/N): ").strip().lower()
        if answer not in {"y", "yes"}:
            print("Stopping at manual checkpoint.")
            sys.exit(0)

        if check_pr_merged(pr_url):
            print("[info] PR merge confirmed.")
            return

        print("[warn] PR is not merged yet. Please merge the PR first.")


def create_public_release(public_repo, version, zip_path_dynamic, zip_path_static):
    for zip_path in (zip_path_dynamic, zip_path_static):
        if not zip_path.exists():
            raise RuntimeError(f"Release archive not found for upload: {zip_path}")

    sha = run_command(
        ["gh", "api", f"repos/{public_repo}/commits/main", "--jq", ".sha"],
        capture_output=True,
    )
    run_command(
        [
            "gh",
            "api",
            f"repos/{public_repo}/git/refs",
            "-f",
            f"ref=refs/tags/{version}",
            "-f",
            f"sha={sha}",
        ]
    )
    run_command(
        [
            "gh",
            "release",
            "create",
            version,
            str(zip_path_dynamic),
            str(zip_path_static),
            "--repo",
            public_repo,
            "--title",
            version,
            "--notes",
            f"Release {version}",
        ]
    )


def parse_args():
    parser = argparse.ArgumentParser(description="Automate the SPM release flow.")
    parser.add_argument("--mode", choices=["test", "release"], default="release")
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

        print(f"[info] Releasing version {version} on branch {branch}")
        build_all_xcframeworks(project, args.mac)
        checksum_dynamic = compute_checksum(zip_path_dynamic)
        checksum_static = compute_checksum(zip_path_static)
        print(f"[info] Checksum (dynamic): {checksum_dynamic}")
        print(f"[info] Checksum (static):  {checksum_static}")

        if args.mode == "test":
            print("[info] Test mode completed (Step 1-2).")
            return

        changes_committed = maybe_commit_and_push(branch, version)
        if changes_committed:
            print("[info] Commit and push completed.")

        private_pr_url = create_private_pr(args.private_repo, branch, version, checksum_dynamic)
        print(f"[info] Private repo PR created: {private_pr_url}")

        wait_for_pr_merge(private_pr_url, "Has the private PR been merged?")
        tag_and_backmerge(version, branch)
        print("[info] Tag created and backmerged into develop.")

        public_pr_url = create_public_pr(
            args.public_repo, version, checksum_dynamic, checksum_static, project
        )
        print(f"[info] Public repo PR created: {public_pr_url}")

        wait_for_pr_merge(public_pr_url, "Has the public PR been merged?")
        create_public_release(args.public_repo, version, zip_path_dynamic, zip_path_static)
        print("[info] Public tag and release created.")
        print(f"[done] Version {version} complete.")
        print(f"       Checksum (dynamic): {checksum_dynamic}")
        print(f"       Checksum (static):  {checksum_static}")
    except Exception as exc:  # pylint: disable=broad-except
        print(f"[error] {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
