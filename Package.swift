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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.2.0/SendbirdAuthSDK.xcframework.zip",
            checksum: "5ae276a996472e0f026fe710049e4b13344d59ab3fccda425ad57fbd407581b1"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.2.0/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "35b82ac5dc53d1a681d7e015b6a78bf1e0406ed0eaf50e6f07e6525d94be4dba"
        ),
    ]
)

