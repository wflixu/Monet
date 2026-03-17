// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Monet",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        // Add dependencies here
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.1.4"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern.git", from: "1.1.0"),
        .package(url: "https://github.com/quassum/SwiftUI-Tooltip.git", from: "1.3.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "Monet",
            dependencies: [
                "SDWebImageSwiftUI",
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                .product(name: "SwiftUITooltip", package: "SwiftUI-Tooltip"),
            ],
            resources: [
                .process("Assets.xcassets"),
            ]
        ),
        .testTarget(
            name: "MonetTests",
            dependencies: ["Monet"]
        ),
    ]
)
