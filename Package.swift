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
            checksum: "0ed1bbf4076355b623fc7bc02d6aa5665c6705ca91a18267a1dcd463a257b8ec"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.10/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "245f512aa100893c1f5d012b486bbc5347abbd7dff2292be06dcaaed678f247b"
        ),
    ]
)

