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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.9/SendbirdAuthSDK.xcframework.zip",
            checksum: "f0ce1d81089b56b8e91c08c5992a877d75822bffdb3ee1522d5b28bdf5419a0e"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.9/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "47ba373032e60ca068193d07ccf8a15ac0f9594dca015d21e30853c1093027de"
        ),
    ]
)

