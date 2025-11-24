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
            name: "SendbirdAuthDynamic",
            type: .dynamic,
            targets: ["SendbirdAuthSDK"]
        ),
    ],
    targets: [
        .target(
            name: "SendbirdAuthSDK",
            swiftSettings: [
                .unsafeFlags(["-enable-library-evolution"]),
                .unsafeFlags(["-package-name", "SendbirdInternal"]),
                .unsafeFlags(["-experimental-package-interface-load"]),
                .define("TESTCASE", .when(configuration: .debug)),
                .unsafeFlags(["-lto=llvm-full"], .when(configuration: .release)),
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
    ]
)
