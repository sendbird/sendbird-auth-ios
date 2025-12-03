import time
import argparse
import os
import subprocess
import sys

"""
Usage:
    python build_script.py -p <project_name> [--static] [--mac]

Arguments:
    -p --project            Required. Specifies the project name which should match the Xcode scheme.
    --mac                   Optional. If included, builds the framework for macOS as well.
    --static                Optional. If included, builds the framework as a static library instead of a dynamic framework.

Examples:
    # Dynamic framework
    python build_script.py -p SendbirdAuthSDK

    # Static framework
    python build_script.py -p SendbirdAuthSDK --static

    # With macOS support
    python build_script.py -p SendbirdAuthSDK --mac

Features:
    1. Generates Xcode project using XcodeGen before building.
    2. Cleans 'build/' and 'release/' directories to remove stale artifacts.
    3. Executes a countdown before cleaning for user confirmation.
    4. Builds the framework for both 'iphoneos' and 'iphonesimulator' targets.
    5. Optionally builds as a static library or a dynamic framework based on the '--static' flag.
    6. Combines build artifacts into an XCFramework.
    7. Packages the XCFramework into a ZIP file for distribution.
    8. Copies LICENSE.md if present into the distribution package.
    9. Cleans up intermediate build artifacts after packaging is complete.
    10. Opens the 'release/' directory after the build process to show the output.

Directory and File Structure:
- build/                    : Temporary directory used to store build archives and final XCFramework.
  - iphoneos.xcarchive/     : Contains the compiled iPhoneOS framework and its debugging symbols.
  - macosx.xcarchive/       : Contains the compiled macOS framework and its debugging symbols.
  - iphonesimulator.xcarchive/ : Contains the compiled iPhoneSimulator framework and its debugging symbols.
  - <project_name>.xcframework/ : The XCFramework combining the iPhoneOS and iPhoneSimulator frameworks.

- release/                  : Directory where the final packaged files are stored.
  - <project_name>.xcframework.zip : The ZIP file containing the XCFramework ready for distribution.
  - <project_name>.zip      : Additional ZIP package for CocoaPods distribution.
"""

# Parse arguments
parser = argparse.ArgumentParser(description='Build framework')
parser.add_argument('-p', required=True, help='Project name. This should also match the scheme name of the project. Ex) SendbirdAuthSDK')
parser.add_argument('--static', required=False, action=argparse.BooleanOptionalAction, help='Boolean flag indicating whether to build the SDK as static library.')
parser.add_argument('--mac', required=False, action=argparse.BooleanOptionalAction, help='Boolean flag indicating whether to build the SDK for macOS.')

args = parser.parse_args()

project_name = args.p
build_static = args.static
build_mac = args.mac
build_dir = "build"
release_dir = "release"

# For static builds, use the Static scheme
if build_static:
    scheme_name = f"{project_name}Static"
    xcframework_name = f"{project_name}Static.xcframework"
    output_name = f"{project_name}Static"
else:
    scheme_name = project_name
    xcframework_name = f"{project_name}.xcframework"
    output_name = project_name

def countdown(seconds):
    """Performs a countdown from the specified number of seconds to 1."""
    for i in range(seconds, 0, -1):
        print(i, end='...', flush=True)
        time.sleep(1)
    print()

def generate_xcode_project():
    """Generate Xcode project using XcodeGen."""
    print("[Release] Generating Xcode project with XcodeGen...")
    subprocess.run(["xcodegen", "generate"], check=True)

def build_command(scheme, sdk, macos=False):
    """Generate the build command for xcodebuild based on input parameters."""
    base_command = [
        "xcodebuild", "clean", "archive",
        "-project", f"{project_name}.xcodeproj",
        "-scheme", scheme,
        "-configuration", "Release",
        "-sdk", sdk,
        "-archivePath", f"{build_dir}/{sdk}.xcarchive",
        "CLANG_ENABLE_CODE_COVERAGE=NO",
        "SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO",
        "GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=NO",
        "GCC_GENERATE_TEST_COVERAGE_FILES=NO",
        "SKIP_INSTALL=NO",
        "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
    ]
    if macos:
        base_command += ["-destination", "platform=macOS", "ARCHS=arm64 x86_64", "VALID_ARCHS=arm64 x86_64"]
    return base_command

def create_xcframework(output_path, build_dir, targets):
    """Create an XCFramework from the provided build directories."""
    command = ["xcodebuild", "-create-xcframework"]
    for sdk in targets:
        framework_path = os.path.join(os.getcwd(), build_dir, f"{sdk}.xcarchive", "Products/Library/Frameworks", f"{project_name}.framework")
        dsym_path = os.path.join(os.getcwd(), build_dir, f"{sdk}.xcarchive", "dSYMs", f"{project_name}.framework.dSYM")
        command.extend(["-framework", framework_path, "-debug-symbols", dsym_path])
    command.extend(["-output", output_path])
    subprocess.run(command, check=True)

if build_static:
    print(f"[Release] Building {project_name} as static framework.")
else:
    print(f"[Release] Building {project_name} as dynamic framework.")

# Remove cache from previous builds
print("[Release] Removing cache from previous build in: ")
countdown(3)

subprocess.run(f"rm -rf {build_dir}", shell=True, check=True)
subprocess.run(f"rm -rf {project_name}.xcodeproj", shell=True, check=True)
os.makedirs(release_dir, exist_ok=True)

# Generate Xcode project
generate_xcode_project()

# Building process
targets = ["iphoneos", "iphonesimulator"]
if build_mac:
    targets.append("macosx")

# Build for each target
for sdk in targets:
    print(f"[Release] Building {scheme_name} for {sdk}.")
    command = build_command(scheme_name, sdk, macos=(sdk == "macosx"))
    subprocess.run(command, check=True)

# Remove unnecessary files
subprocess.run(f"find {build_dir} -type f -name \"*.abi.json\" -delete", shell=True, check=True)
subprocess.run(f"find {build_dir} -type f -name \"*.xctestplan\" -delete", shell=True, check=True)

# Create XCFramework
print("[Release] Creating XCFramework")
create_xcframework(f"{build_dir}/{xcframework_name}", build_dir, targets)

# Finish up and cleanup
os.chdir(build_dir)

print("[Release] Creating release packages")

# GitHub Release ZIP
subprocess.run(f"zip -r ../{release_dir}/{xcframework_name}.zip {xcframework_name}", shell=True, check=True)

# CocoaPods package
os.makedirs(output_name, exist_ok=True)
if os.path.exists("../LICENSE.md"):
    subprocess.run(f"cp -r ../LICENSE.md {output_name}", shell=True, check=True)
subprocess.run(f"cp -r {xcframework_name} {output_name}", shell=True, check=True)
subprocess.run(f"zip -r ../{release_dir}/{output_name}.zip {output_name}", shell=True, check=True)

# Copy xcframework to release
subprocess.run(f"cp -R {xcframework_name} ../{release_dir}/", shell=True, check=True)

os.chdir("..")

# Cleanup
print("[Release] Cleaning up...")
subprocess.run(f"rm -rf {build_dir}", shell=True, check=True)
subprocess.run(f"rm -rf {project_name}.xcodeproj", shell=True, check=True)

print("[Release] Done!")
print(f"")
print(f"Output files in {release_dir}/:")
print(f"  - {xcframework_name}")
print(f"  - {xcframework_name}.zip (GitHub Release)")
print(f"  - {output_name}.zip (CocoaPods)")

subprocess.run(f"open {release_dir}", shell=True)
