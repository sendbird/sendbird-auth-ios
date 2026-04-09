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
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.0/SendbirdAuthSDK.xcframework.zip",
            checksum: "f5e688b8688f49080db225d1468e1b26b6a1aa40f5d8de63b48dbc1849a1545b"
        ),
        .binaryTarget(
            name: "SendbirdAuthSDKStatic",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/1.1.0/SendbirdAuthSDKStatic.xcframework.zip",
            checksum: "d669a07f628b639f0bda759891d6ebd657827e49de5f7792a39e29c454f14c5d"
        ),
    ]
)

