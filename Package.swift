// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "VenomInjector",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_14),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "VenomInjector",
            targets: ["VenomInjector"])
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
