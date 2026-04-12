// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TaboraSparkle",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "TaboraSparkle",
            targets: ["TaboraSparkle"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            from: "2.9.1"
        ),
    ],
    targets: [
        .target(
            name: "TaboraSparkle",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
    ]
)
