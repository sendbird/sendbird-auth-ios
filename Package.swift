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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.8/SendbirdAuthSDK.xcframework.zip",
            checksum: "c018d2e1cb313d4f3f26eca8941e0410740484a3ace5c48346dba8cc8ef8ceb8"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.8/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "214821e14b9a5b605a91edfb1e97362d9cd5e2404e7ed37e80f437de8a40a3e3"
        ),
    ]
)
