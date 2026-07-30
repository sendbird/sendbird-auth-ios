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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.5/SendbirdAuthSDK.xcframework.zip",
            checksum: "e41ff9beb22d505c6245165d3ea4bbe0f1e1b757c94b029817682e26dc470c2c"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.5/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "80dcea7b137184054902b48f4da79b97ea3c1f31f3437a654244bde5dc399d23"
        ),
    ]
)

