#!/usr/bin/env python3
"""
Full Release: Orchestrates all release phases with PR merge prompts.

Flow:
1. Run spm_release_phase1.py (build, checksum, private PR)
2. Wait for "Private PR merged? (y/n)"
3. Run spm_release_phase2.py (tag, backmerge, public PR)
4. Wait for "Public PR merged? (y/n)"
5. Run spm_release_phase3.py (GitHub release)
6. Run pod_release.py (CocoaPods)
"""

import argparse
import sys

from release_common import (
    ROOT,
    check_pr_merged,
    load_release_state,
    run_command,
)


def run_script(script_name, extra_args=None):
    """Run a release script."""
    cmd = [sys.executable, str(ROOT / "script" / script_name)]
    if extra_args:
        cmd.extend(extra_args)
    run_command(cmd)


def wait_for_pr_merge(pr_url, label):
    """Wait for user confirmation and verify PR is merged."""
    print("")
    print(f"[wait] {label}")
    print(f"       PR: {pr_url}")
    print("")

    while True:
        answer = input("Is merged? (y/n): ").strip().lower()
        if answer == "n":
            print("[info] Stopping. Run the next phase script manually after merging.")
            sys.exit(0)

        if answer == "y":
            if check_pr_merged(pr_url):
                print("[info] PR merge confirmed.")
                return
            print("[warn] PR is not merged yet. Please merge the PR first.")
        else:
            print("[info] Please enter 'y' or 'n'.")


def parse_args():
    parser = argparse.ArgumentParser(description="Full release (SPM + CocoaPods).")
    parser.add_argument("--mac", action="store_true", help="Include macOS in SPM build.")
    parser.add_argument("--project", default="SendbirdAuthSDK")
    parser.add_argument("--private-repo", default="sendbird/auth-ios")
    parser.add_argument("--public-repo", default="sendbird/sendbird-auth-ios")
    parser.add_argument(
        "--build-if-missing",
        action="store_true",
        help="Allow building XCFramework if CocoaPods zip is missing.",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    try:
        print("=" * 60)
        print("[phase 1/4] Build and create Private PR")
        print("=" * 60)

        phase1_args = ["--project", args.project, "--private-repo", args.private_repo, "--public-repo", args.public_repo]
        if args.mac:
            phase1_args.append("--mac")
        run_script("spm_release_phase1.py", phase1_args)

        # Wait for private PR merge
        state = load_release_state()
        wait_for_pr_merge(state["private_pr_url"], "Private PR merge required")

        print("")
        print("=" * 60)
        print("[phase 2/4] Tag, backmerge, and create Public PR")
        print("=" * 60)

        run_script("spm_release_phase2.py")

        # Wait for public PR merge
        state = load_release_state()
        wait_for_pr_merge(state["public_pr_url"], "Public PR merge required")

        print("")
        print("=" * 60)
        print("[phase 3/4] Create GitHub Release")
        print("=" * 60)

        run_script("spm_release_phase3.py")

        print("")
        print("=" * 60)
        print("[phase 4/4] CocoaPods Release")
        print("=" * 60)

        pod_args = ["--public-repo", args.public_repo, "--version", state["version"]]
        if args.build_if_missing:
            pod_args.append("--build-if-missing")
        run_script("pod_release.py", pod_args)

        print("")
        print("=" * 60)
        print(f"[done] Full release complete for version {state['version']}")
        print("=" * 60)

    except Exception as exc:
        print(f"[error] {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
