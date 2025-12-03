#!/usr/bin/env python3
"""
Automate the CocoaPods release flow described in .claude/pod-release/SKILL.md.

Modes:
- release (default): full flow including trunk push
- test: stops after lint (no trunk push)
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = "SendbirdAuthSDK"
RELEASE_ZIP = ROOT / "release" / f"{PROJECT}.zip"
PODSPEC_PATH = ROOT / f"{PROJECT}.podspec"


def run_command(cmd, *, cwd=None, capture_output=False):
    """Run a shell command and optionally return stdout."""
    print(f"[cmd] {' '.join(cmd)}")
    result = subprocess.run(
        cmd,
        cwd=cwd,
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
    if match:
        return match.group(1)
    raise RuntimeError("Provide --version or checkout a release/X.X.X branch.")


def ensure_spm_release(version, public_repo):
    run_command(["gh", "release", "view", version, "--repo", public_repo])


def ensure_trunk_ready():
    run_command(["pod", "trunk", "me"])
    run_command(["pod", "trunk", "info", PROJECT])


def ensure_zip(build_if_missing):
    if RELEASE_ZIP.exists():
        print(f"[info] Found release archive: {RELEASE_ZIP}")
        return
    if not build_if_missing:
        raise RuntimeError(f"Missing {RELEASE_ZIP}. Build first or pass --build-if-missing.")
    run_command(["python3", str(ROOT / "script" / "build_xcframework.py"), "-p", PROJECT])
    if not RELEASE_ZIP.exists():
        raise RuntimeError(f"Build did not produce {RELEASE_ZIP}")


def compute_sha1():
    output = run_command(["shasum", str(RELEASE_ZIP)], capture_output=True)
    return output.split()[0]


def generate_podspec(version, sha1):
    run_command(
        [
            str(ROOT / "script" / "generate_podspec.sh"),
            "-v",
            version,
            "-s",
            sha1,
        ]
    )


def lint_podspec():
    run_command(["unzip", "-o", str(RELEASE_ZIP), "-d", str(ROOT)])
    run_command(["pod", "lib", "lint", f"{PROJECT}.podspec", "--allow-warnings"])
    run_command(["pod", "spec", "lint", f"{PROJECT}.podspec", "--allow-warnings"])
    run_command(["rm", "-rf", str(ROOT / PROJECT)])


def trunk_push():
    run_command(["pod", "trunk", "push", f"{PROJECT}.podspec", "--allow-warnings"])
    run_command(["pod", "trunk", "info", PROJECT])


def parse_args():
    parser = argparse.ArgumentParser(description="CocoaPods release automation.")
    parser.add_argument("--mode", choices=["release", "test"], default="release")
    parser.add_argument("--version", help="Release version (defaults to release/X.X.X branch name).")
    parser.add_argument("--public-repo", default="sendbird/sendbird-auth-ios")
    parser.add_argument(
        "--build-if-missing",
        action="store_true",
        help=f"Build the XCFramework archive if {RELEASE_ZIP.name} is missing.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    version = args.version or detect_version()

    try:
        print(f"[info] Starting CocoaPods {args.mode} flow for {version}")
        ensure_trunk_ready()
        ensure_spm_release(version, args.public_repo)
        ensure_zip(args.build_if_missing)

        sha1 = compute_sha1()
        print(f"[info] SHA1: {sha1}")

        generate_podspec(version, sha1)
        lint_podspec()

        if args.mode == "test":
            print("[info] Test mode complete (lint only).")
            return

        trunk_push()
        print(f"[done] CocoaPods release complete for {version}")
    except Exception as exc:  # pylint: disable=broad-except
        print(f"[error] {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
