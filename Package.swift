// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RenderKit",
    platforms: [
        .iOS("17.0"),
        .macOS("14.0"),
        .macCatalyst("17.0"),
    ],
    products: [
        .library(
            name: "RenderKit",
            targets: ["RenderKit"]
        ),
        .library(
            name: "RenderKitDemo",
            targets: ["RenderKitDemo"]
        ),
        .library(
            name: "RenderKitSceneGraph",
            targets: ["RenderKitSceneGraph"]
        ),
        .executable(name: "RenderKitCTL", targets: ["RenderKitCTL"]),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/Everything", branch: "main"),
        .package(url: "https://github.com/schwa/MetalSupport", branch: "main"),
        .package(url: "https://github.com/schwa/SIMD-Support", branch: "main"),
        .package(url: "https://github.com/schwa/SwiftGLTF", branch: "main"),
    ],
    targets: [
        .target(
            name: "RenderKit",
            dependencies: [
                "RenderKitSupport",
                "Everything",
                "MetalSupport",
                .product(name: "SIMDSupport", package: "SIMD-Support"),
                "Shaders",
                "SwiftGLTF",
            ]
        ),
        .target(
            name: "RenderKitSupport",
            dependencies: [
                "MetalSupport",
                "Everything",
            ]
        ),
        .target(
            name: "RenderKitSceneGraph",
            dependencies: [
                "RenderKit",
                "MetalSupport",
                "Everything",
            ]
        ),
        .target(
            name: "RenderKitDemo",
            dependencies: [
                "RenderKit",
                "RenderKitSceneGraph",
            ]
        ),
        .target(
            name: "Shaders",
            dependencies: [
            ]
        ),
        .testTarget(
            name: "RenderKitTests",
            dependencies: ["RenderKit"]
        ),
        .executableTarget(
            name: "RenderKitCTL",
            dependencies: ["RenderKit", "RenderKitSceneGraph", "RenderKitDemo"]
        )
    ]
)
