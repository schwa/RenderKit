@testable import RenderKit
import XCTest

// final class RenderKitTests: XCTestCase {
//    func testExample() throws {
//        let library: ShaderLibrary = try YAMLDecoder().decode(from: renderFile)
//        print(library)
//    }
// }
//
// let renderFile = """
// ---
// types:
//  - name: Vertex
//    attributes:
//      - name: position
//        type: float2
//      - name: color
//        type: float4
//  - name: Uniforms
//    attributes:
//      - name: worldTransform
//        type: float3x4
//      - name: color
//        type: float4
//  - name: Fragment
//    attributes:
//      - name: position
//        type: float4
// shaders:
// - name: SolidColorVertexShader
//  type: vertex
//  parameters:
//    - name: vertices
//      index: 0
//      typeName: Vertex
//      kind: vertices
//    - name: uniforms
//      index: 1
//      typeName: Uniforms
//      kind: uniform
//  output:
//    - type: Fragment
// - name: SolidColorFragmentShader
//  type: fragment
//  parameters:
//    - name: uniforms
//      index: 0
//      typeName: Uniforms
//      kind: uniform
//  input:
//    - typeName: Fragment
// """
