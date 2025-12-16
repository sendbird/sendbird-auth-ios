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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.5/SendbirdAuthSDK.xcframework.zip",
            checksum: "1d815d44edc969c983a635ef38d720008b9c350b9e6b6adcf24615b719c6fa45"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.5/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "4750a430d0670cb6d2d418152b86730a215b3c12bc3e62594b8f7a2c69975316"
        ),
    ]
)
