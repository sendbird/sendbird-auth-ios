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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.99.99/SendbirdAuthSDK.xcframework.zip",
            checksum: "63f02e61035a4a93b73a7efbf1edfe428c918af6f28aea73ae7efd2a1b2729b5"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.99.99/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "e33a4a0a72c82740960333627ed7aff1cb3233c686bcb0a313968d682f72cba3"
        ),
    ]
)

