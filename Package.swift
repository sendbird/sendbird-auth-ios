// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SendbirdAuthSDK",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "SendbirdAuthSDK",
            targets: ["SendbirdAuthSDK"]
        ),
        .library(
            name: "SendbirdAuthSDKStatic",
            targets: ["SendbirdAuthSDKStatic"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "SendbirdAuthSDK",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.11/SendbirdAuthSDK.xcframework.zip",
            checksum: "bfe0c7e7002561c3e379c19c5ccea45def4468f1817082e209d4163054edadd0"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.11/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "39fd78277311a017cf7f2ae301e2733090e2d2db638f70574b020f8f73d52c3c"
        ),
    ]
)

