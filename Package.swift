// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RenderKitClassic",
    platforms: [
        .iOS("16.0"),
        .macOS("13.0"),
        .macCatalyst("16.0"),
    ],
    products: [
        .library(name: "RenderKit", targets: ["RenderKit"]),
        .library(name: "RenderKitShaders", targets: ["RenderKitShaders"]),
    ],
    dependencies: [
        .package(name: "Everything", url: "https://github.com/schwa/Everything", from: "0.0.1"),
        .package(url: "https://github.com/schwa/SIMD-Support", from: "0.0.1")
    ],
    targets: [
        .target(name: "RenderKit", dependencies: [
            "Everything",
            "RenderKitShaders",
            .product(name: "SIMDSupport", package: "SIMD-Support")
        ]),
        .target(name: "RenderKitShaders", resources: [
            .process("CLUTPixelBufferShaders.metal"),
            .process("Phong.metal"),
            .process("PixelBufferShaders.metal"),
            .process("PixelBufferYCbCrSubrenderer.metal"),
            .process("SimpleWireframe.metal"),
            .process("Skydome.metal"),
            .process("SphereDemo.metal"),
        ], cSettings: [
            .define("CXX", to: "1"),
        ]),
        .testTarget(name: "RenderKitTests", dependencies: ["RenderKit"]),
    ]
)
