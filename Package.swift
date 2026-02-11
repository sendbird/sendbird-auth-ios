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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.10/SendbirdAuthSDK.xcframework.zip",
            checksum: "4d0c0484f9d90757341c6513a6e04500df04a8d110268ca60692dd2a8c0ef4f5"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.10/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "3a88f1e4d414834f69565288f0a22fea57b67e6d87068eb7c33fa14132e0b508"
        ),
    ]
)

