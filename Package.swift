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
        .package(url: "https://github.com/schwa/Everything", from: "0.1.2"),
        .package(url: "https://github.com/schwa/MetalSupport", from: "0.1.0"),
        .package(url: "https://github.com/schwa/SIMD-Support", from: "0.1.1"),
        .package(url: "https://github.com/schwa/SwiftGLTF", branch: "0.0.3"),
        .package(url: "https://github.com/schwa/UnsafeConformances", branch: "0.0.1"),
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
                "UnsafeConformances",
            ],
            resources: [
                .copy("Models/Cube.ply"),
                .copy("Models/Teapot.mtl"),
                .copy("Models/Teapot.ply"),
                .copy("Models/teapot.obj"),
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
            ],
            resources: [
                .process("Media.xcassets"),
                .copy("Voxels/1x1.vox"),
                .copy("Voxels/1x1x2.vox"),
                .copy("Voxels/1x2x3.vox"),
                .copy("Voxels/2x1.vox"),
                .copy("Voxels/2x2.vox"),
                .copy("Voxels/2x2x2.vox"),
                .copy("Voxels/3x1x1.vox"),
                .copy("Voxels/gap.vox"),
                .copy("Voxels/monu0.vox"),
                .copy("Voxels/monu1.vox"),
                .copy("Voxels/monu10.vox"),
                .copy("Voxels/monu16.vox"),
                .copy("Voxels/monu2.vox"),
                .copy("Voxels/monu3.vox"),
                .copy("Voxels/monu4.vox"),
                .copy("Voxels/monu5.vox"),
                .copy("Voxels/monu6-without-water.vox"),
                .copy("Voxels/monu6.vox"),
                .copy("Voxels/monu7.vox"),
                .copy("Voxels/monu8-without-water.vox"),
                .copy("Voxels/monu8.vox"),
                .copy("Voxels/monu9.vox"),
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
