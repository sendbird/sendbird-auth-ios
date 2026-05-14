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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.2/SendbirdAuthSDK.xcframework.zip",
            checksum: "2ac5512c21c4198c0ac562aa5a348b0a05b1648166ff76d35ace58b73de1e900"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.2/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "cb049845454d7e1d590268b1a9349c101cc720e06b450bac46c2f1113e88065f"
        ),
    ]
)

