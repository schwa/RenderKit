// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RenderKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "RenderKit",
            targets: ["RenderKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/Everything", from: "0.2.0"),
        .package(url: "https://github.com/schwa/MetalSupport", from: "0.2.0"),
        //.package(url: "https://github.com/schwa/RenderKit", branch: "main"),
        .package(url: "https://github.com/schwa/SIMD-Support", from: "0.1.1"),
        .package(url: "https://github.com/schwa/CoreGraphicsGeometrySupport", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/schwa/swiftformats", from: "0.3.0"),
        .package(url: "https://github.com/schwa/swiftfields", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "RenderKit",
            dependencies: [
                "CoreGraphicsGeometrySupport",
                "Everything",
                "Shaders",
                .product(name: "MetalSupport", package: "MetalSupport"),
                .product(name: "MetalSupportUnsafeConformances", package: "MetalSupport"),
                //.product(name: "RenderKitSupport", package: "RenderKit"),
                .product(name: "SIMDSupport", package: "SIMD-Support"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "SwiftFields", package: "swiftfields"),
                .product(name: "SwiftFormats", package: "swiftformats"),

            ],
            resources: [
                .process("Media.xcassets")
            ],
            swiftSettings: [
                .enableExperimentalFeature("VariadicGenerics")
            ]
        ),
        .target(name: "Shaders"),
        .testTarget(
            name: "RenderKitTests",
            dependencies: ["RenderKit"]),
    ]
)
