import simd

public extension LineSegment3D {
    func intersection(with other: LineSegment3D) -> LineSegment3D? {
        // https://stackoverflow.com/a/565282/273118
        let p = start
        let q = other.start
        let r = direction
        let s = other.direction

        let rCrossS = simd.cross(r, s)
        let qMinusP = q - p
        let qMinusPCrossR = simd.cross(qMinusP, r)

        let t = simd.dot(qMinusPCrossR, rCrossS) / simd.dot(rCrossS, rCrossS)
        let u = simd.dot(qMinusPCrossR, rCrossS) / simd.dot(rCrossS, rCrossS)

        if t >= 0, t <= 1, u >= 0, u <= 1 {
            return LineSegment3D(start: start + t * direction, end: start + t * direction)
        }
        else {
            return nil
        }
    }
}

public extension Line3D {
    enum LineSphereIntersection {
        case once(SIMD3<Float>)
        case twice(SIMD3<Float>, SIMD3<Float>)
    }

    func intersects(sphere: Sphere) -> LineSphereIntersection? {
        fatalError()
    }
}
