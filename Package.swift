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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.2.1/SendbirdAuthSDK.xcframework.zip",
            checksum: "5739ba832b2bca942eab5a75dbdcb7ccda367e6cb792522f0c7cdbe4fd541fe0"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.2.1/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "56d50594b23428f2cef43d87a06788f5e384af9342009870d5fb395ab85e3a28"
        ),
    ]
)

