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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.3/SendbirdAuthSDK.xcframework.zip",
            checksum: "680105922a5c0696501d6f9c23772591b7e81e573302531d50adf2b3048f9727"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.3/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "acf164aa8f323968c7d24d0701ec514cfb038fd0c91eda8e792703d138f2df27"
        ),
    ]
)

