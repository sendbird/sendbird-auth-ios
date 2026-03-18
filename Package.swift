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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.0.0/SendbirdAuthSDK.xcframework.zip",
            checksum: "df97c59200cff9be97469061b0212d4b74215272b33685db8d02aad59a928cf7"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.0.0/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "1a9d8874908559c4be03f6ddd92278da9f24338bede032d8993cc3ade79f76bb"
        ),
    ]
)

