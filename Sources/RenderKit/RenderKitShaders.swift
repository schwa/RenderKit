//
//  File.swift
//  
//
//  Created by Jonathan Wight on 6/30/23.
//

import Foundation

public extension Bundle {
    static var shadersBundle: Bundle = {
        // Step 1. Find the bundle as a child of main bundle.
        if let shadersBundleURL = Bundle.main.url(forResource: "RenderKit_RenderKitShaders", withExtension: "bundle"), let bundle = Bundle(url: shadersBundleURL) {
            return bundle
        }
        // Step 2. Find the bundle as peer to the current `Bundle.module`
        if let bundle = Bundle(url: Bundle.module.bundleURL.deletingLastPathComponent().appendingPathComponent("RenderKit_RenderKitShaders.bundle")) {
            return bundle
        }
        // Fail.
        fatalError("Could not find shaders bundle")
    }()
}
