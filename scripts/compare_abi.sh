#!/bin/bash

## This script compares the ABI of two different commits of a SendbirdAuthSDK framework.
## It creates `abi_results.txt` file that contains: 
## - raw results of api-digester
## - ABI changes by category 
## - summary of the ABI changes

## ** abi_results.txt **

# [ABI Comparison Results]
# Base commit: temp_base_branch
# Target commit: temp_target_branch
# Date: Mon Apr 14 08:37:24 UTC 2025

# ## Raw Comparison Output ##
# ```

# /* Generic Signature Changes */

# /* RawRepresentable Changes */

# /* Removed Decls */

# /* Moved Decls */

# /* Renamed Decls */

# /* Type Changes */

# /* Decl Attribute changes */

# /* Fixed-layout Type Changes */

# /* Protocol Conformance Change */

# /* Protocol Requirement Change */

# /* Class Inheritance Change */

# /* Others */
# ```

# ## Analysis by Category ##

# ## Summary ##
# Breaking changes detected: No
# Total changes found: 0

# FOUND_CHANGES=false

# Check if the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <target_name> <base_branch_or_commit> <target_branch_or_commit>"
    echo "i.e.: $0 SendbirdAuthSDK origin/main release/1.0.0"
    exit 1
fi

TARGET_NAME=$1
BASE_COMMIT=$2
TARGET_COMMIT=$3

# Classes to ignore in ABI comparison
IGNORED_CLASSES=""

# Derived data paths
BASE_BUILD_DIR=".build_base"
TARGET_BUILD_DIR=".build_target"

# SDK path
SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"

# Print all available iOS simulators
echo "📱 Available simulators:"
xcrun simctl list devices available -j

# Print all available iOS simulators
echo "📱 Available iOS simulators:"
xcrun simctl list devices available -j | jq -r '.devices | to_entries[] | select(.key | contains("iOS")) | .value[] | select(.isAvailable == true) | "\(.name) (\(.udid))"'

# Print all available iOS runtimes/versions
echo "📱 Available iOS runtimes:"
xcrun simctl list runtimes available | grep iOS

# Print all available destinations for the target scheme
echo "🎯 Available destinations for $TARGET_NAME scheme:"
xcodebuild -scheme "$TARGET_NAME" -showdestinations

# Find an available iPhone simulator
SIMULATOR_ID=$(xcrun simctl list devices available -j | jq -r '.devices | to_entries[] | select(.key | contains("iOS")) | .value[] | select(.isAvailable == true) | .udid' | head -n 1)

if [ -z "$SIMULATOR_ID" ]; then
    echo "No available iPhone simulators found. Exiting with status 1..."
    exit 1
fi

echo "Using simulator(ID): $SIMULATOR_ID"
DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"

# Save the original branch to go back to it at the end
ORIGINAL_BRANCH=$TARGET_COMMIT

#######################
##### Base Commit #####
#######################
# Clean up untracked files before checkout
echo "Cleaning up untracked files before checkout..."
git clean -fd 2>/dev/null || true

# Checkout base commit and build
echo "Checking out base commit: $BASE_COMMIT"
git checkout $BASE_COMMIT
if [ $? -ne 0 ]; then
    echo "Failed to checkout base commit $BASE_COMMIT"
    exit 1
fi

# Sync submodules and clean up removed submodule directories
echo "Syncing submodules for base commit..."
git submodule sync --recursive
git submodule update --init --recursive
git clean -ffd  # Remove untracked directories (including removed submodules)

echo "Running xcodegen..."
xcodegen generate

echo "Building base commit..."
xcodebuild -derivedDataPath $BASE_BUILD_DIR -sdk iphonesimulator -scheme "$TARGET_NAME" -destination "$DESTINATION" -configuration Release | xcpretty

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Base build failed. Check the build logs for errors."
    git checkout $ORIGINAL_BRANCH
    exit 1
fi

echo "✅ Base branch build succeeded."

# Generate the base ABI file path
BASE_ABI_PATH="$BASE_BUILD_DIR/Build/Products/Release-iphonesimulator/$TARGET_NAME.framework/Modules/$TARGET_NAME.swiftmodule/arm64-apple-ios-simulator.abi.json"
echo "BASE_ABI_PATH: $BASE_ABI_PATH"

#########################
##### Target Commit #####
#########################
# Clean up untracked files before checkout
echo "Cleaning up untracked files before checkout..."
git clean -fd -e .build_base 2>/dev/null || true

# Checkout target commit and build
echo "Checking out target commit: $TARGET_COMMIT"
git checkout $TARGET_COMMIT
if [ $? -ne 0 ]; then
    echo "Failed to checkout target commit $TARGET_COMMIT"
    exit 1
fi

# Sync submodules and clean up removed submodule directories
echo "Syncing submodules for target commit..."
git submodule sync --recursive
git submodule update --init --recursive
git clean -ffd -e .build_base  # Remove untracked directories (including removed submodules)

echo "Running xcodegen..."
xcodegen generate

echo "Building target commit..."
xcodebuild -derivedDataPath $TARGET_BUILD_DIR -sdk iphonesimulator -scheme "$TARGET_NAME" -destination "$DESTINATION" -configuration Release | xcpretty

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Target build failed. Check the build logs for errors."
    git checkout $ORIGINAL_BRANCH
    exit 1
fi

echo "✅ Target branch build succeeded."

# Generate the target ABI file path
TARGET_ABI_PATH="$TARGET_BUILD_DIR/Build/Products/Release-iphonesimulator/$TARGET_NAME.framework/Modules/$TARGET_NAME.swiftmodule/arm64-apple-ios-simulator.abi.json"
echo "TARGET_ABI_PATH: $TARGET_ABI_PATH"

##################################
##### Run swift api-digester #####
##################################
# Check if ABI files exist
if [ ! -f "$BASE_ABI_PATH" ]; then
    echo "Error: Base ABI file not found at $BASE_ABI_PATH"
    echo "Available files in directory:"
    ls -la "$(dirname "$BASE_ABI_PATH")"
    git checkout $ORIGINAL_BRANCH
    exit 1
fi

if [ ! -f "$TARGET_ABI_PATH" ]; then
    echo "Error: Target ABI file not found at $TARGET_ABI_PATH"
    echo "Available files in directory:"
    ls -la "$(dirname "$TARGET_ABI_PATH")"
    git checkout $ORIGINAL_BRANCH
    exit 1
fi

# Compare the ABI files using swift api-digester
echo "Comparing ABI files..."
OUTPUT_FILE="${BASE_BUILD_DIR}_${TARGET_BUILD_DIR}.txt"
swift api-digester -diagnose-sdk -input-paths $BASE_ABI_PATH -input-paths $TARGET_ABI_PATH -o "$OUTPUT_FILE"

# cat "$OUTPUT_FILE"

# ###################################################
# ##### Output final results in abi_results.txt #####
# ###################################################
# Define the categories to check
CATEGORIES=(
    "Generic Signature Changes"
    "RawRepresentable Changes"
    "Removed Decls"
    "Moved Decls"
    "Renamed Decls"
    "Type Changes"
    "Decl Attribute changes"
    "Fixed-layout Type Changes"
    "Protocol Conformance Change"
    "Protocol Requirement Change"
    "Class Inheritance Change"
    "Others"
)

FOUND_CHANGES=false
TOTAL_CHANGES=0
CHANGES_BY_CATEGORY=""

# Create abi_results.txt file
RESULTS_FILE="abi_results.txt"

# Paste the raw results to abi_results.txt
BASE_BRANCH_NAME=$(git rev-parse --abbrev-ref "$BASE_COMMIT" 2>/dev/null || git rev-parse --short "$BASE_COMMIT")
TARGET_BRANCH_NAME=$(git rev-parse --abbrev-ref "$TARGET_COMMIT" 2>/dev/null || git rev-parse --short "$TARGET_COMMIT")

echo "[ABI Comparison Results Report]" > "$RESULTS_FILE"
echo "Base commit: $BASE_BRANCH_NAME" >> "$RESULTS_FILE"
echo "Target commit: $TARGET_BRANCH_NAME" >> "$RESULTS_FILE"
echo "Date: $(date)" >> "$RESULTS_FILE"
if [ -n "$IGNORED_CLASSES" ]; then
  echo "Ignored classes: $IGNORED_CLASSES" >> "$RESULTS_FILE"
fi
echo "" >> "$RESULTS_FILE"

echo "## Raw Comparison Output ##" >> "$RESULTS_FILE"
echo '```' >> "$RESULTS_FILE"
cat "$OUTPUT_FILE" >> "$RESULTS_FILE"
echo '```' >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Show changes by Category
echo "## Analysis by Category ##" >> "$RESULTS_FILE"

# Function to filter out ignored classes from diff output
filter_ignored_classes() {
  local diff_content="$1"
  local filtered_content="$diff_content"

  if [ -n "$IGNORED_CLASSES" ]; then
    IFS=',' read -ra CLASS_ARRAY <<< "$IGNORED_CLASSES"
    for class in "${CLASS_ARRAY[@]}"; do
      class=$(echo "$class" | xargs)  # Trim whitespace
      if [ -n "$class" ]; then
        # Filter out lines containing the ignored class name
        filtered_content=$(echo "$filtered_content" | grep -v "$class" || true)
      fi
    done
  fi

  echo "$filtered_content"
}

# Check each category for content
for CATEGORY in "${CATEGORIES[@]}"; do
  # Extract content between category markers
  CATEGORY_DIFF=$(sed -n "/\/\* $CATEGORY \*\//,/\/\* /p" $OUTPUT_FILE | grep -v "^\s*\/\* " | grep -v "^\s*$")

  # Filter out ignored classes
  CATEGORY_DIFF=$(filter_ignored_classes "$CATEGORY_DIFF")

  if [ -n "$CATEGORY_DIFF" ]; then
    COUNT=$(echo "$CATEGORY_DIFF" | wc -l)
    FOUND_CHANGES=true
    TOTAL_CHANGES=$((TOTAL_CHANGES + COUNT))
    echo "======== Found changes in category: $CATEGORY ========"
    echo "$CATEGORY_DIFF"
    echo
    CHANGES_BY_CATEGORY+="$CATEGORY, "

    # Add to results file
    echo "### $CATEGORY ($COUNT changes)" >> "$RESULTS_FILE"
    echo '```' >> "$RESULTS_FILE"
    echo "$CATEGORY_DIFF" >> "$RESULTS_FILE"
    echo '```' >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
  fi
done

if [ "$FOUND_CHANGES" = "true" ]; then
    echo "" >> "$RESULTS_FILE"
else 
    echo "No changes" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
fi

# Show summary of changes 
echo "## Summary ##" >> "$RESULTS_FILE"
if [ "$FOUND_CHANGES" = "true" ]; then
  echo "Breaking changes detected: Yes" >> "$RESULTS_FILE"
  echo "Total changes found: $TOTAL_CHANGES" >> "$RESULTS_FILE"
  echo "Affected categories: ${CHANGES_BY_CATEGORY::-2}" >> "$RESULTS_FILE"
else
  echo "Breaking changes detected: No" >> "$RESULTS_FILE"
  echo "Total changes found: 0" >> "$RESULTS_FILE"
fi
echo "" >> "$RESULTS_FILE"

# Also add raw value for programmatic parsing
echo "FOUND_CHANGES=$FOUND_CHANGES" >> "$RESULTS_FILE"


# ##################
# ##### Finish #####
# ##################

# Go back to the original branch
git checkout $ORIGINAL_BRANCH

echo "Comparison complete. Results saved to: $RESULTS_FILE"
