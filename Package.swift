// swift-tools-version:5.9

import Foundation
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
    ],
    targets: [
        .target(
            name: "SendbirdAuthSDK",
            path: "Sources/SendbirdAuth",
            swiftSettings: swiftSettings
        ),
    ]
)

var swiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
    .define("RELEASE", .when(configuration: .release)),
]
