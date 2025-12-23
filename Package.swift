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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.7/SendbirdAuthSDK.xcframework.zip",
            checksum: "0340c48426f3be819bf2d42ccf362f114dda7a0cf58f121458e2744399d0264c"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.7/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "ab9a3a3a6eb719b17bc00703f11a9572aef6830e86d23bde84ec0316bc38be7f"
        ),
    ]
)
