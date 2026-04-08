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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.0.2/SendbirdAuthSDK.xcframework.zip",
            checksum: "c1e575bcc95eb85a162247f7ea5021289150eac54e39c5574581d762cd4950b2"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.0.2/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "3fbaf05e4c20349b278b33c78ba6178b91a7c3f0bde0358ac2ab60cdac59c444"
        ),
    ]
)

