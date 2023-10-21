// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Compute",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/schwa/Everything.git", from: "0.5.0"),
        .package(url: "https://github.com/schwa/SIMD-Support.git", from: "0.2.0"),
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "compute",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Everything", package: "Everything"),
                .product(name: "SIMDSupport", package: "SIMD-Support"),
                .product(name: "TOMLKit", package: "TOMLKit"),
            ]
        ),
    ]
)
