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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.1/SendbirdAuthSDK.xcframework.zip",
            checksum: "02eea102ff34ad5d8fa3ee317d0854066a5a6f2d75d96d59e712b8f1141e9cc4"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.1/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "a42a840b70c565b0c3ca86b6779b030331bf17d412d759fd5beb6b895d7efc7d"
        ),
    ]
)

