import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct GeometryTests {
    @Test func snapsNearHorizontal() {
        let p = Geometry.constrainTo45Degrees(from: .zero, to: CGPoint(x: 100, y: 10))
        #expect(abs(p.y) < 1e-9)
        #expect(abs(p.x - 100) < 1e-9)
    }

    @Test func snapsNearDiagonal() {
        let p = Geometry.constrainTo45Degrees(from: .zero, to: CGPoint(x: 100, y: 90))
        #expect(abs(p.x - p.y) < 1e-9)
    }

    @Test func zeroLengthUnchanged() {
        let p = Geometry.constrainTo45Degrees(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 5, y: 5))
        #expect(p == CGPoint(x: 5, y: 5))
    }
}
