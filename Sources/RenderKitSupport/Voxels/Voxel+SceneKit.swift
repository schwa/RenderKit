/*
 import Foundation
 import SceneKit
 import simd

 public extension MagicaVoxelModel {
     func generateSCNNode(scale: SIMD3<Float> = [0.01, 0.01, 0.01]) -> SCNNode {
 //        let nsColors = self.colors.map() { color -> NSColor in
 //            let color = SIMD4 <Float> (color) * 255
 //            return NSColor(deviceRed: CGFloat(color[0]), green: CGFloat(color[1]), blue: CGFloat(color[2]), alpha: CGFloat(color[3]))
 //        }

         // let vectors = SCNVector3(<#T##v: SIMD3<Double>##SIMD3<Double>#>)

         let vertices = [SIMD3<Float>]([
             [0, 0, 0],
             [1, 0, 0],
             [0, 1, 0],
             [1, 1, 0],
             [0, 0, 1],
             [1, 0, 1],
             [0, 1, 1],
             [1, 1, 1],
         ])
         .map {
             $0 * [100, 100, 100]
         }
         .map {
             SCNVector3($0)
         }
         let source = SCNGeometrySource(vertices: vertices)
         let indices: [Int] = [
             3, 1, 0,
 //            0, 1, 2,
 //
 //            0, 1, 2,
 //            0, 1, 2,
 //
 //            0, 1, 2,
 //            0, 1, 2,
 //
 //            0, 1, 2,
 //            0, 1, 2,
 //
 //            0, 1, 2,
 //            0, 1, 2,
 //
 //            0, 1, 2,
 //            0, 1, 2,
         ]
         let elements = SCNGeometryElement(indices: indices, primitiveType: .triangles)
         let geometry = SCNGeometry(sources: [source], elements: [elements])
         let red = SCNMaterial()
         red.emission.contents = CGColor.red
         geometry.materials.append(red)

         let cube = SCNNode(geometry: geometry)
         return cube

 //        let offset = SIMD3 <Float> (size) * -0.5 * scale
 //        let voxelNodes: [SCNNode] = voxels.map({ voxel in
 //            let colorIndex = voxel.1
 //            let material = SCNMaterial()
 //            let color = nsColors[colorIndex]
 //            material.emission.contents = color
 //
 //            let cubeGeometry = SCNBox(width: CGFloat(scale.x), height: CGFloat(scale.y), length: CGFloat(scale.z), chamferRadius: 0)
 //            let cube = SCNNode(geometry: cubeGeometry)
 //            let voxelPosition = SIMD3 <UInt8> ([voxel.0.x, voxel.0.z, voxel.0.y])
 //            cube.simdPosition = SIMD3 <Float> (voxelPosition) * scale + offset
 //            cubeGeometry.materials.append(material)
 //            return cube
 //        })
 //
 //        let node = SCNNode()
 //        voxelNodes.forEach({ node.addChildNode($0) })
 //        return node//.flattenedClone()
     }
 }
 */
