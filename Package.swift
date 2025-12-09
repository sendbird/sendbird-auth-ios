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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.4/SendbirdAuthSDK.xcframework.zip",
            checksum: "824ec0d2df9908ae8c1c3aef2516627c06ce5ceab224da26a6c4a2b77373e4ed"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.4/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "bc3c91ba3328d3ed11740aabb4b83eb7b4bc02e48820650d0d3942da885a5b77"
        ),
    ]
)
