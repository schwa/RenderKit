// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Compute",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Compute",
            targets: ["Compute"]),
    ],
    targets: [
        .target(name: "Compute"),
        .executableTarget(name: "ComputeTool", dependencies: ["Compute"], resources: [
            .process("BitonicSort.metal"),
            .process("GPULifeKernel.metal"),
            .process("RandomFill.metal"),
        ]),
    ]
)
