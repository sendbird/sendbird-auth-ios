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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.3/SendbirdAuthSDK.xcframework.zip",
            checksum: "422af3473e6aafff63d3910851b6c03307f894ccc2a89222666ae132fe1be20e"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.3/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "d1686a716854ce258f9964eeffd8e63dba4d34c6899e85818948ea45a5d29ed5"
        ),
    ]
)
