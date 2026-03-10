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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.12/SendbirdAuthSDK.xcframework.zip",
            checksum: "98c638098de77275fc255eb2daa41e101bc44fb5ca882bd897f1b6802f918284"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.12/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "049eba5b038a69daa1f215407ef7389304f94a435298b981a777991994ee37c7"
        ),
    ]
)

