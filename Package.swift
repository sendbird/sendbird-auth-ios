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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.0.1/SendbirdAuthSDK.xcframework.zip",
            checksum: "1b44ff0ded4bd2dab332bf2e77ad5c50069db846bfa11dc845f2cd5ded2a91f8"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.0.1/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "807cb1ebf4758b38f088bfef2f627884672fac53ee7967745dc842f92ff11385"
        ),
    ]
)

