////
////  File.swift
////
////
////  Created by Jonathan Wight on 12/29/19.
////
//
// import Everything
// @testable import RenderKit
// import XCTest
//
// final class CLayoutStrategyTests: XCTestCase {
//    func testBlob() throws {
//        let structure = try StructureDefinition(name: "Blob", attributes: [
//            Attribute(name: "position", kind: .packed_float2),
//            Attribute(name: "velocity", kind: .packed_float2),
//            Attribute(name: "radius", kind: .float),
//            Attribute(name: "color", kind: .packed_float4),
//        ])
//        let cOffsets = try structure.cOffsets2()
//        let layout = structure.layout(strategy: CLayoutStrategy.self)
//        for attribute in structure.attributes {
//            XCTAssertEqual(layout.attributeLayouts[attribute.name]!.offset, cOffsets.members[attribute.name]!.offset)
//        }
//        XCTAssertEqual(layout.alignment, cOffsets.alignment)
//        XCTAssertEqual(layout.stride, cOffsets.size)
//    }
//
//    func testBlobUniforms() throws {
//        let structure = try StructureDefinition(name: "BlobUniforms", attributes: [
//            Attribute(name: "transform", kind: .float3x4),
//            Attribute(name: "blobCount", kind: .int),
//        ])
//        try validate(structure: structure)
//    }
//
//    func testSimpleVertex() throws {
//        let structure = try StructureDefinition(name: "SimpleVertex", attributes: [
//            Attribute(name: "position", kind: .packed_float2),
//            Attribute(name: "color", kind: .packed_float4),
//        ])
//        try validate(structure: structure)
//    }
//
//    func testUniforms1() throws {
//        let structure = try StructureDefinition(name: "Uniforms", attributes: [
//            Attribute(name: "worldTransform", kind: .float3x4),
//            Attribute(name: "color", kind: .float4),
//        ])
//        try validate(structure: structure)
//    }
// }
//

// MARK: -

//
// func validate(structure: StructureDefinition) throws {
//    let layout = structure.layout(strategy: CLayoutStrategy.self)
//    let cOffsets = try structure.cOffsets2()
//    for attribute in structure.attributes {
//        XCTAssertEqual(layout.attributeLayouts[attribute.name]!.offset, cOffsets.members[attribute.name]!.offset)
//    }
//    XCTAssertEqual(layout.alignment, cOffsets.alignment)
//    XCTAssertEqual(layout.stride, cOffsets.size)
// }
//
// extension StructureDefinition {
//    func toC() -> String {
//        let members = attributes.map { attribute in
//            "\t\(attribute.kind.cName) \(attribute.name);"
//        }
//        return (["struct \(name) {"] + members + ["};"]).joined(separator: "\n")
//    }
// }
//
// struct CStructDefinition2: Decodable {
//    struct Member: Decodable {
//        let size: Int
//        let alignment: Int
//        let offset: Int
//        let isStandardLayout: Bool
//        let isScalar: Bool
//    }
//
//    let size: Int
//    let alignment: Int
//    let isStandardLayout: Bool
//    let isScalar: Bool
//    let members: [String: Member]
// }
//
// extension Encodable {
//    func toYAML() throws -> String {
//        return try YAMLEncoder().encode(self)
//    }
// }
//
// extension StructureDefinition {
//    func cOffsets2() throws -> CStructDefinition2 {
//        func member(attribute: Attribute) -> String {
//            let member = """
//            cout << "  \(attribute.name):" << endl;
//            cout << "    size: " << sizeof(\(name)::\(attribute.name)) << endl;
//            cout << "    alignment: " << alignof(\(name)::\(attribute.name)) << endl;
//            cout << "    offset: " << offsetof(\(name), \(attribute.name)) << endl;
//            cout << "    isStandardLayout: " << (is_standard_layout<decltype(\(name)::\(attribute.name))>::value ? "true" : "false") << endl;
//            cout << "    isScalar: " << (is_scalar<decltype(\(name)::\(attribute.name))>::value ? "true" : "false") << endl;
//            """
//            return member
//        }
//
//        let program = """
//        #include <iostream>
//        #include <simd/simd.h>
//        #include <stddef.h>
//
//        using namespace std;
//
//        \(toC())
//
//        int main() {
//            cout << "size: " << sizeof(\(name)) << endl;
//            cout << "alignment: " << alignof(\(name)) << endl;
//            cout << "isStandardLayout: " << (is_standard_layout<\(name)>::value ? "true" : "false") << endl;
//            cout << "isScalar: " << (is_scalar<\(name)>::value ? "true" : "false") << endl;
//            cout << "members:" << endl;
//        \(attributes.map(member).joined(separator: "\n"))
//        }
//        """
//        let tempDir = try FSPath.makeTemporaryDirectory()
//        try program.write(to: (tempDir / "program.cpp").url, atomically: true, encoding: .utf8)
//        let compilation = try Process.checkOutput(launchPath: "/usr/bin/clang++", arguments: ["-std=c++17", "-stdlib=libc++", "-o", "program", "program.cpp"], currentDirectoryURL: tempDir.url)
//        let result = try Process.checkOutput(launchPath: (tempDir / "program").path, arguments: [], currentDirectoryURL: tempDir.url).standardOutputString
//        return try YAMLDecoder().decode(from: result)
//    }
// }
