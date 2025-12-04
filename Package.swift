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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.2/SendbirdAuthSDK.xcframework.zip",
            checksum: "a920d79c2dd77b872b0804122a0fde8f02e5c80053ca5a226fabced0675ddef9"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.2/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "3c7e84cfa3ae97a8f1a131be14deb27119481adb3a5c5dffb23e532a5c673906"
        ),
    ]
)
