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
            path: "Frameworks/SendbirdAuthSDK.xcframework"
        ),
    ]
)
