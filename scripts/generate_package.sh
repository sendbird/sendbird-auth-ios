#!/bin/bash

# Usage: generate_package.sh -v VERSION -c CHECKSUM_DYNAMIC -s CHECKSUM_STATIC -p PROJECT_NAME -r REPO_NAME
# Matches output of spm_release_phase2.py render_public_package()

VERSION=''
CHECKSUM_DYNAMIC=''
CHECKSUM_STATIC=''
PROJECT_NAME='SendbirdAuthSDK'
REPO_NAME='sendbird-auth-ios'

while getopts v:c:s:p:r: flag
do
    case "${flag}" in
        v) VERSION=${OPTARG};;
        c) CHECKSUM_DYNAMIC=${OPTARG};;
        s) CHECKSUM_STATIC=${OPTARG};;
        p) PROJECT_NAME=${OPTARG};;
        r) REPO_NAME=${OPTARG};;
        *) echo "Unexpected option ${flag}" && exit 1;;
    esac
done

if [ -z "$VERSION" ]; then
    echo 'Version is required (-v)'
    exit 1
fi

if [ -z "$CHECKSUM_DYNAMIC" ]; then
    echo 'Dynamic checksum is required (-c)'
    exit 1
fi

if [ -z "$CHECKSUM_STATIC" ]; then
    echo 'Static checksum is required (-s)'
    exit 1
fi

URL_DYNAMIC="https://github.com/sendbird/$REPO_NAME/releases/download/$VERSION/$PROJECT_NAME.xcframework.zip"
URL_STATIC="https://github.com/sendbird/$REPO_NAME/releases/download/$VERSION/${PROJECT_NAME}Static.xcframework.zip"

TEMPLATE="// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: \"$PROJECT_NAME\",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: \"$PROJECT_NAME\",
            targets: [\"$PROJECT_NAME\"]
        ),
        .library(
            name: \"${PROJECT_NAME}Static\",
            targets: [\"${PROJECT_NAME}Static\"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: \"$PROJECT_NAME\",
            url: \"$URL_DYNAMIC\",
            checksum: \"$CHECKSUM_DYNAMIC\"
        ),
        .binaryTarget(
            name: \"${PROJECT_NAME}Static\",
            url: \"$URL_STATIC\",
            checksum: \"$CHECKSUM_STATIC\"
        ),
    ]
)
"

echo "$TEMPLATE" > Package.swift
echo "Generated Package.swift for $PROJECT_NAME version $VERSION"
echo "  Dynamic checksum: $CHECKSUM_DYNAMIC"
echo "  Static checksum:  $CHECKSUM_STATIC"
