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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.9/SendbirdAuthSDK.xcframework.zip",
            checksum: "51fa0136cbcdc08a44cbe782a15a87e18ab29270a5801b0c5ff143ad193f05ef"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.9/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "9321ceb40c3432c66b428caa102cb714fb25ffcde30afe075c779e1d88bc3b96"
        ),
    ]
)

