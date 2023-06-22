import CoreGraphics
import Everything
import simd

public extension MagicaVoxelModel {
    enum Orientation {
        case xy
        case xz
        case yz
    }

    func slice(z layer: Int, orientation: Orientation = .xy) -> Array2D<SIMD4<UInt8>> {
        let voxels = Dictionary(uniqueKeysWithValues: voxels)
        var colorbuffer = Array2D<SIMD4<UInt8>>(repeating: [0, 0, 0, 0], size: IntSize(width: Int(size.x), height: Int(size.y)))

        let size = SIMD3<Int>(self.size.map(Int.init))

        let axis: SIMD3<Int>
        let increment: SIMD3<Int>
        let outputx: SIMD3<Int>
        let outputy: SIMD3<Int>

        switch orientation {
        case .xy:
            axis = [1, 1, 0]
            increment = [0, 0, 1]
            outputx = [1, 0, 0]
            outputy = [0, 1, 0]
        case .xz:
            axis = [1, 0, 1]
            increment = [0, 1, 0]
            outputx = [1, 0, 0]
            outputy = [0, 0, 1]
        case .yz:
            axis = [0, 1, 1]
            increment = [1, 0, 0]
            outputx = [0, 1, 0]
            outputy = [0, 0, 1]
        }

        let start = layer &* increment
        let end = ((size &+ [1, 1, 1]) &* axis) &+ (layer &* increment)

        for x in start.x ... end.x {
            for y in start.y ... end.y {
                for z in start.z ... end.z {
                    let input: SIMD3<Int> = [x, y, z]
                    let key = SIMD3<UInt8>(input.map({ UInt8($0) }))
                    guard let voxel = voxels[key] else {
                        continue
                    }
                    let color = colors[Int(voxel)]
                    let output: SIMD2 = [(input &* outputx).reduce(0, &+), (input &* outputy).reduce(0, &+)]
                    colorbuffer[output.x, output.y] = color
                }
            }
        }
        return colorbuffer
    }

    func sliceImage(z: Int) -> CGImage {
        slice(z: z).cgImage
    }
}
