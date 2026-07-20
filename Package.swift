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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.4/SendbirdAuthSDK.xcframework.zip",
            checksum: "748afa59e709798125eb40d101075366b70b123739e87b516dfecffad343848f"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.4/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "845fbc51699e2c3c74c2efdb50614970d1a2fd42dc88d558aa29fb5d50e1f449"
        ),
    ]
)

