// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SendbirdAuthSDK",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "SendbirdAuthSDK",
            targets: ["SendbirdAuthSDK"]
        ),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "SendbirdAuthSDK",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/0.0.1/SendbirdAuthSDK.xcframework.zip",
            checksum: "738557c09494d1dfcb1debbc92d81d695ed5419f2726ca2d20d4def8102ea7ba"
        ),
    ]
)
