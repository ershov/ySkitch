import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct ArrowGeometryTests {
    let pink = RGBAColor(hex: 0xFF2E6C)

    func vertices(_ path: CGPath) -> [CGPoint] {
        var points: [CGPoint] = []
        path.applyWithBlock { element in
            let e = element.pointee
            if e.type == .moveToPoint || e.type == .addLineToPoint { points.append(e.points[0]) }
        }
        return points
    }

    func headWidth(tail: CGPoint, head: CGPoint, thickness: CGFloat) -> CGFloat {
        let v = vertices(ArrowGeometry.path(tail: tail, head: head, thickness: thickness))
        return abs(v[2].y - v[4].y)
    }

    @Test func headIsVertex() {
        let head = CGPoint(x: 100, y: 50)
        let v = vertices(ArrowGeometry.path(tail: CGPoint(x: 10, y: 50), head: head, thickness: 4))
        #expect(v.count == 7)
        #expect(v.contains(head))
    }

    @Test func verticesNearSegment() {
        let tail = CGPoint(x: 10, y: 20)
        let head = CGPoint(x: 90, y: 70)
        let t: CGFloat = 6
        let limit = hypot(head.x - tail.x, head.y - tail.y) + ArrowGeometry.headLength(thickness: t)
        for p in vertices(ArrowGeometry.path(tail: tail, head: head, thickness: t)) {
            #expect(hypot(p.x - tail.x, p.y - tail.y) <= limit)
        }
    }

    @Test func headGrowsWithThickness() {
        let tail = CGPoint(x: 0, y: 50)
        let head = CGPoint(x: 200, y: 50)
        let thin = headWidth(tail: tail, head: head, thickness: 2)
        let thick = headWidth(tail: tail, head: head, thickness: 10)
        #expect(thick > thin)
        #expect(thin == ArrowGeometry.headWidth(thickness: 2))
    }

    @Test func shortArrowKeepsWithinSegmentExtent() {
        let tail = CGPoint(x: 10, y: 50)
        let head = CGPoint(x: 20, y: 50)
        for p in vertices(ArrowGeometry.path(tail: tail, head: head, thickness: 8)) {
            #expect(p.x >= tail.x - 0.001 && p.x <= head.x + 0.001)
        }
    }

    @Test func shortArrowNarrowsShaft() {
        let t: CGFloat = 20
        let length: CGFloat = 40
        let v = vertices(ArrowGeometry.path(tail: .zero, head: CGPoint(x: length, y: 0), thickness: t))
        let effective = length / ArrowGeometry.minimumLengthToWidthRatio
        #expect(abs(v[1].y - v[5].y) <= effective + 0.001)
        #expect(abs(v[2].y - v[4].y) > abs(v[1].y - v[5].y))
    }

    @Test func longArrowIsUnchanged() {
        let t: CGFloat = 10
        let length = t * ArrowGeometry.minimumLengthToWidthRatio
        let v = vertices(ArrowGeometry.path(tail: .zero, head: CGPoint(x: length, y: 0), thickness: t))
        #expect(abs(v[1].y - v[5].y) == t)
        let longer = vertices(ArrowGeometry.path(tail: .zero, head: CGPoint(x: 300, y: 0), thickness: t))
        #expect(abs(longer[1].y - longer[5].y) == t)
        #expect(abs(longer[0].y - longer[6].y) == ArrowGeometry.tailWidthRatio * t)
    }

    @Test func headStaysWiderThanShaft() {
        for t: CGFloat in [4, 40] {
            var length: CGFloat = 0.5
            while length <= 200 {
                let v = vertices(ArrowGeometry.path(tail: .zero, head: CGPoint(x: length, y: 0), thickness: t))
                #expect(v.count == 7)
                #expect(abs(v[2].y - v[4].y) > abs(v[1].y - v[5].y))
                length += 0.5
            }
        }
    }

    @Test func subPointArrowIsValid() {
        let path = ArrowGeometry.path(tail: .zero, head: CGPoint(x: 0.3, y: 0), thickness: 8)
        #expect(!path.isEmpty)
        #expect(vertices(path).count == 7)
    }

    @Test func zeroLengthIsEmpty() {
        let p = CGPoint(x: 5, y: 5)
        #expect(ArrowGeometry.path(tail: p, head: p, thickness: 4).isEmpty)
    }

    private func render(_ shape: AnnotationShape, thickness: CGFloat = 6) -> (Int, Int) -> Pixel {
        var doc = Document(blankSize: CGSize(width: 200, height: 100), scale: 1)
        doc.annotations = [Annotation(style: AnnotationStyle(color: pink, thickness: thickness), shape: shape)]
        return readPixels(Renderer.flatten(doc)).pixel
    }

    private func isPink(_ p: Pixel) -> Bool {
        abs(Int(p.r) - 0xFF) <= 8 && abs(Int(p.g) - 0x2E) <= 8 && abs(Int(p.b) - 0x6C) <= 8
    }

    @Test func arrowPixels() {
        let at = render(.arrow(tail: CGPoint(x: 20, y: 50), head: CGPoint(x: 180, y: 50)))
        #expect(isPink(at(175, 50)))
        let off = at(30, 70)
        #expect(off.r >= 245 && off.g >= 245 && off.b >= 245)
    }

    @Test func linePixels() {
        let at = render(.line(start: CGPoint(x: 20, y: 50), end: CGPoint(x: 180, y: 50)))
        #expect(isPink(at(100, 50)))
        #expect(isPink(at(21, 50)))
        let off = at(100, 70)
        #expect(off.r >= 245 && off.g >= 245 && off.b >= 245)
    }

    @Test func renderBoundsContainVertices() {
        let shape = AnnotationShape.arrow(tail: CGPoint(x: 120, y: 80), head: CGPoint(x: 20, y: 30))
        let annotation = Annotation(style: AnnotationStyle(color: pink, thickness: 8), shape: shape)
        guard case .arrow(let tail, let head) = shape else { return }
        for p in vertices(ArrowGeometry.path(tail: tail, head: head, thickness: 8)) {
            #expect(annotation.renderBounds.contains(p))
        }
    }

    @Test func lineRenderBounds() {
        let annotation = Annotation(
            style: AnnotationStyle(color: pink, thickness: 8),
            shape: .line(start: CGPoint(x: 10, y: 20), end: CGPoint(x: 50, y: 30)))
        let outset = 4 + OutlineStyle.extent(outlineWidth: OutlineStyle.whiteWidth(forLineWidth: 8))
        #expect(annotation.renderBounds == CGRect(x: 10, y: 20, width: 40, height: 10).insetBy(dx: -outset, dy: -outset))
    }
}
