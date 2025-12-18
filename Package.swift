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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.6/SendbirdAuthSDK.xcframework.zip",
            checksum: "334c923110ed9a5fde34ba0a5e7628fce8058d81794f47b96cddd83e5b7dd755"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.6/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "9ba59d6a09ec639124c490f488ef00f39135ef6692993b42bca7e94c03b77d71"
        ),
    ]
)
