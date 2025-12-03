#!/usr/bin/env python3
"""
Orchestration script for SendbirdAuthSDK full release (SPM + CocoaPods).

Mode:
- release (default): Run full SPM flow through CocoaPods trunk push
- test: Run SPM build/checksum only and CocoaPods lint
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run_command(cmd, *, capture_output=False):
    """Helper to run shell commands."""
    print(f"[cmd] {' '.join(cmd)}")
    result = subprocess.run(
        cmd,
        text=True,
        capture_output=capture_output,
    )
    if result.returncode != 0:
        if capture_output:
            sys.stderr.write(result.stdout)
            sys.stderr.write(result.stderr)
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(cmd)}")
    return result.stdout.strip() if capture_output else None


def detect_version():
    branch = run_command(["git", "branch", "--show-current"], capture_output=True)
    match = re.match(r"^release/([0-9]+\.[0-9]+\.[0-9]+)$", branch or "")
    if not match:
        raise RuntimeError("Current branch is not release/X.X.X. Use --version option.")
    return match.group(1)


def parse_args():
    parser = argparse.ArgumentParser(description="Automate full release (SPM + CocoaPods).")
    parser.add_argument("--mode", choices=["release", "test"], default="release")
    parser.add_argument("--project", default="SendbirdAuthSDK")
    parser.add_argument("--static", action="store_true", help="Build SPM as the static variant.")
    parser.add_argument("--mac", action="store_true", help="Include macOS in the SPM build.")
    parser.add_argument("--private-repo", default="sendbird/auth-ios")
    parser.add_argument("--public-repo", default="sendbird/sendbird-auth-ios")
    parser.add_argument("--auto-continue", action="store_true", help="Skip prompt while waiting for SPM PR merge.")
    parser.add_argument(
        "--build-if-missing",
        action="store_true",
        help="Allow running build_xcframework.py when the CocoaPods zip is missing.",
    )
    return parser.parse_args()


def run_spm_phase(args):
    cmd = [
        sys.executable,
        str(ROOT / "script" / "spm_release.py"),
        "--mode",
        args.mode,
        "--project",
        args.project,
        "--private-repo",
        args.private_repo,
        "--public-repo",
        args.public_repo,
    ]
    if args.static:
        cmd.append("--static")
    if args.mac:
        cmd.append("--mac")
    if args.auto_continue:
        cmd.append("--auto-continue")
    run_command(cmd)


def run_pod_phase(args, version):
    cmd = [
        sys.executable,
        str(ROOT / "script" / "pod_release.py"),
        "--mode",
        args.mode,
        "--public-repo",
        args.public_repo,
        "--version",
        version,
    ]
    if args.build_if_missing:
        cmd.append("--build-if-missing")
    run_command(cmd)


def main():
    args = parse_args()
    version = detect_version()

    try:
        print(f"[info] Starting full release ({args.mode}) - version {version}")
        print("[phase] 1/2 SPM Release")
        run_spm_phase(args)
        print("[phase] 2/2 CocoaPods Release")
        run_pod_phase(args, version)
        if args.mode == "test":
            print("[done] Test mode complete (SPM build/checksum + CocoaPods lint).")
        else:
            print("[done] Full release complete (SPM + CocoaPods).")
    except Exception as exc:  # pylint: disable=broad-except
        print(f"[error] {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
