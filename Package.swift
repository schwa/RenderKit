// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RenderKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "RenderKit", targets: ["RenderKit"]),
        .library(name: "RenderKitScratch", targets: ["RenderKitScratch"]),
        .library(name: "RenderKitShaders", targets: ["RenderKitShaders"]),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/Everything", branch: "jwight/downsizing"),
        .package(url: "https://github.com/schwa/SwiftGraphics", branch: "jwight/develop"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/schwa/swiftformats", from: "0.3.3"),
        .package(url: "https://github.com/schwa/swiftfields", from: "0.1.3"),
        .package(url: "https://github.com/schwa/MetalCompilerPlugin", from: "0.0.2"),
        //.package(url: "https://github.com/schwa/StreamBuilder", branch: "main"),
    ],
    targets: [
        .target(
            name: "RenderKit",
            dependencies: [
                "Everything",
                "RenderKitShaders",
                .product(name: "CoreGraphicsSupport", package: "SwiftGraphics"),
                .product(name: "MetalSupport", package: "SwiftGraphics"),
                .product(name: "MetalSupportUnsafeConformances", package: "SwiftGraphics"),
                .product(name: "SIMDSupport", package: "SwiftGraphics"),
                .product(name: "LegacyGraphics", package: "SwiftGraphics"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "SwiftFields", package: "swiftfields"),
                .product(name: "SwiftFormats", package: "swiftformats"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                //                .product(name: "StreamBuilder", package: "StreamBuilder"),
            ],
            resources: [
                //                .process("Media.xcassets"),
                .process("VisionOS/Assets.xcassets"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("VariadicGenerics"),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "RenderKitShaders",
            plugins: [
                //                .plugin(name: "MetalCompilerPlugin", package: "MetalCompilerPlugin")
            ]
        ),
        .target(
            name: "RenderKitScratch",
            dependencies: [
                "Everything",
                "RenderKit",
            ]
        ),
        .testTarget(
            name: "RenderKitTests",
            dependencies: ["RenderKit", "RenderKitScratch"]),
    ]
)
