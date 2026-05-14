// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "pushy_flutter",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "pushy-flutter", targets: ["pushy_flutter"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/pushy/pushy-sdk-ios",
            from: "1.0.65"
        ),
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "pushy_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "Pushy", package: "pushy-sdk-ios")
            ]
        )
    ]
)
