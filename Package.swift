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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.2.3/SendbirdAuthSDK.xcframework.zip",
            checksum: "6340927153041a64b3cdebfff4fb8aa434baac929081015e4bd06970cec3c035"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.2.3/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "24f5ef85fb5eceb45904e1f3d14ffffb4c420fcd6046cb210a3ef1865b262306"
        ),
    ]
)

