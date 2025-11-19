// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SendbirdAuth",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "SendbirdAuth",
            targets: ["SendbirdAuth"]
        ),
        .library(
            name: "SendbirdAuthDynamic",
            type: .dynamic,
            targets: ["SendbirdAuth"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/sendbird/sendbird-starscream", .revision("2b08226")),
        .package(url: "https://github.com/sendbird/GzipSwift", .revision("6ade77a")),
    ],
    targets: [
        .target(
            name: "SendbirdAuth",
            dependencies: [
                .product(name: "Starscream", package: "sendbird-starscream"),
                .product(name: "Gzip", package: "GzipSwift"),
            ],
            swiftSettings: [
                .unsafeFlags(["-package-name", "SendbirdInternal"]),
                .define("TESTCASE", .when(configuration: .debug)),
                .unsafeFlags(["-lto=llvm-full"], .when(configuration: .release)),
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
    ]
)
