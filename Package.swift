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
            checksum: "2de1bb244833d78f7a82d576fdb348864a6ed562060dbe3ed54cbbcadd6fc612"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.6/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "f395312b84a0b2de0448fd9b700ac75e2e5737609ac7509c029f9cbbe592ee5f"
        ),
    ]
)
