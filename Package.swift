// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "VenomInjector",
    platforms: [
        .iOS(.v16),
        .macOS(.v10_14),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "VenomInjector",
            targets: ["VenomInjector"]),
        .library(
            name: "VenomInjector-Static",
            type: .static,
            targets: ["VenomInjector"]),
        .library(
            name: "VenomInjector-Dynamic",
            type: .dynamic,
            targets: ["VenomInjector"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VenomInjector",
            dependencies: []),
        .testTarget(
            name: "VenomInjectorTests",
            dependencies: ["VenomInjector"]),
    ]
)
