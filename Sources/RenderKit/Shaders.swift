//
//  File.swift
//  
//
//  Created by Jonathan Wight on 6/30/23.
//

import Foundation

extension Bundle {

    static var shaders: Bundle {
        guard let url = Bundle.main.url(forResource: "RenderKit_Shaders", withExtension: "bundle") else {
            fatalError()
        }
        guard let shaders = Bundle(url: url) else {
            fatalError()
        }
        return shaders
    }
}
