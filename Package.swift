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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.2.2/SendbirdAuthSDK.xcframework.zip",
            checksum: "d46fcc14d8e714c66e808dd63975dfae24379c71881bccbaae328cbf4f2eda81"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.2.2/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "8e74fc8e20bf118733e76519bc4497a504864ef2c4d6936955ee7b0c332437c6"
        ),
    ]
)

