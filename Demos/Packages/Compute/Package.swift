// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Compute",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Compute",
            targets: ["Compute"]),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/SwiftGraphics", branch: "jwight/develop")
    ],
    targets: [
        .target(name: "Compute", dependencies: [
            .product(name: "MetalSupport", package: "SwiftGraphics"),
            .product(name: "CoreGraphicsSupport", package: "SwiftGraphics"),
        ]),
        .executableTarget(name: "ComputeTool", dependencies: ["Compute"], resources: [
            .process("BitonicSort.metal"),
            .process("GameOfLife.metal"),
            .process("RandomFill.metal"),
        ]),
    ]
)
