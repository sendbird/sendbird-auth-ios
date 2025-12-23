#!/usr/bin/env python3
"""
SPM Release Phase 3: Create GitHub Release with XCFramework assets.

This script performs (after Public PR is merged):
1. Create tag on public repo main branch
2. Create GitHub Release
3. Upload XCFramework zip files

Input: release/release_state.json (from phase2)
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from release_common import (
    ROOT,
    load_release_state,
    run_command,
)


def create_public_release(public_repo, version, project):
    """Create tag and GitHub release on public repo."""
    zip_path_dynamic = ROOT / "release" / f"{project}.xcframework.zip"
    zip_path_static = ROOT / "release" / f"{project}Static.xcframework.zip"

    for zip_path in (zip_path_dynamic, zip_path_static):
        if not zip_path.exists():
            raise RuntimeError(f"Release archive not found for upload: {zip_path}")

    # Get main branch SHA
    sha = run_command(
        ["gh", "api", f"repos/{public_repo}/commits/main", "--jq", ".sha"],
        capture_output=True,
    )

    # Create tag
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

    # Create release with assets
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


def main():
    try:
        state = load_release_state()
        version = state["version"]
        project = state["project"]
        public_repo = state["public_repo"]
        checksum_dynamic = state["checksum_dynamic"]
        checksum_static = state["checksum_static"]

        print(f"[info] Phase 3: Version {version}")

        # Create release
        create_public_release(public_repo, version, project)
        print("[info] Public tag and GitHub release created.")

        print(f"[done] SPM Release complete for version {version}")
        print(f"       Checksum (dynamic): {checksum_dynamic}")
        print(f"       Checksum (static):  {checksum_static}")
        print("")
        print("[next] Run pod_release.py to publish to CocoaPods.")

    except Exception as exc:
        print(f"[error] {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
