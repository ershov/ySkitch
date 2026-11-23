import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct FreehandTests {
    static let scale: CGFloat = 2
    static let pink = RGBAColor(hex: 0xFF2E6C)

    func elements(_ path: CGPath) -> [(type: CGPathElementType, point: CGPoint)] {
        var result: [(CGPathElementType, CGPoint)] = []
        path.applyWithBlock { element in
            let e = element.pointee
            let count = switch e.type {
            case .addQuadCurveToPoint: 2
            case .addCurveToPoint: 3
            case .closeSubpath: 0
            default: 1
            }
            result.append((e.type, count > 0 ? e.points[count - 1] : .zero))
        }
        return result
    }

    @Test func pathStartsAndEndsAtStrokeEnds() {
        let points = [CGPoint(x: 1, y: 2), CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 5), CGPoint(x: 40, y: 40)]
        let e = elements(StrokeSmoothing.path(points))
        #expect(e.first?.type == .moveToPoint)
        #expect(e.first?.point == points[0])
        #expect(e.last?.type == .addLineToPoint)
        #expect(e.last?.point == points[3])
        #expect(e.contains { $0.type == .addQuadCurveToPoint })
    }

    @Test func singlePointIsZeroLengthSegment() {
        let p = CGPoint(x: 5, y: 6)
        let e = elements(StrokeSmoothing.path([p]))
        #expect(e.count == 2)
        #expect(e[0].type == .moveToPoint && e[0].point == p)
        #expect(e[1].type == .addLineToPoint && e[1].point == p)
    }

    @Test func twoPointsAreStraightLine() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 10, y: 10)
        let e = elements(StrokeSmoothing.path([a, b]))
        #expect(e.count == 2)
        #expect(e[1].type == .addLineToPoint && e[1].point == b)
    }

    @Test func boundsCoverPointsAndStroke() {
        let points = [CGPoint(x: 10, y: 20), CGPoint(x: 50, y: 40)]
        let style = AnnotationStyle(color: Self.pink, thickness: 8)
        let pen = Annotation(style: style, shape: .pen(points: points))
        let highlighter = Annotation(style: style, shape: .highlighter(points: points))
        #expect(pen.bounds == CGRect(x: 10, y: 20, width: 40, height: 20))
        #expect(highlighter.renderBounds == CGRect(x: 6, y: 16, width: 48, height: 28))
        #expect(pen.renderBounds.contains(highlighter.renderBounds))
        #expect(pen.renderBounds.width > highlighter.renderBounds.width)
    }

    func line(from a: CGPoint, to b: CGPoint, steps: Int = 40) -> [CGPoint] {
        (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }

    func render(_ shape: AnnotationShape, thickness: CGFloat = 10, black: Bool = false) -> (CGFloat, CGFloat) -> Pixel {
        var doc: Document
        if black {
            let px = 200
            let cg = makeImage(
                width: px, height: px,
                pixels: Array(repeating: Pixel(r: 0, g: 0, b: 0, a: 255), count: px * px))
            doc = Document(image: BaseImage(cgImage: cg, scale: Self.scale))
        } else {
            doc = Document(blankSize: CGSize(width: 100, height: 100), scale: Self.scale)
        }
        doc.annotations = [Annotation(style: AnnotationStyle(color: Self.pink, thickness: thickness), shape: shape)]
        let p = readPixels(Renderer.flatten(doc))
        return { x, y in p.pixel(Int(x * Self.scale), Int(y * Self.scale)) }
    }

    func near(_ p: Pixel, _ r: Int, _ g: Int, _ b: Int, tolerance: Int) -> Bool {
        abs(Int(p.r) - r) <= tolerance && abs(Int(p.g) - g) <= tolerance && abs(Int(p.b) - b) <= tolerance
    }

    @Test func penPixelsAndOutline() {
        let at = render(.pen(points: line(from: CGPoint(x: 20, y: 50), to: CGPoint(x: 80, y: 50))), black: true)
        #expect(near(at(50, 50), 0xFF, 0x2E, 0x6C, tolerance: 8))
        let ring = at(50, 50 - 5 - 1)
        #expect(ring.r >= 230 && ring.g >= 230 && ring.b >= 230)
    }

    @Test func penSinglePointRendersDot() {
        let at = render(.pen(points: [CGPoint(x: 50, y: 50)]))
        #expect(near(at(50, 50), 0xFF, 0x2E, 0x6C, tolerance: 8))
    }

    @Test func highlighterOverWhite() {
        let at = render(.highlighter(points: line(from: CGPoint(x: 20, y: 50), to: CGPoint(x: 80, y: 50))))
        #expect(near(at(50, 50), 255, 171, 196, tolerance: 4))
    }

    @Test func highlighterSelfOverlapDoesNotDarken() {
        var points = line(from: CGPoint(x: 10, y: 50), to: CGPoint(x: 90, y: 50))
        points += line(from: CGPoint(x: 90, y: 50), to: CGPoint(x: 50, y: 10))
        points += line(from: CGPoint(x: 50, y: 10), to: CGPoint(x: 50, y: 90))
        let at = render(.highlighter(points: points))
        let crossing = at(50, 50)
        let single = at(25, 50)
        #expect(abs(Int(crossing.r) - Int(single.r)) <= 3)
        #expect(abs(Int(crossing.g) - Int(single.g)) <= 3)
        #expect(abs(Int(crossing.b) - Int(single.b)) <= 3)
    }

    @Test func highlighterOverBlackStaysBlack() {
        let at = render(.highlighter(points: line(from: CGPoint(x: 20, y: 50), to: CGPoint(x: 80, y: 50))), black: true)
        let p = at(50, 50)
        #expect(p.r <= 10 && p.g <= 10 && p.b <= 10)
    }
}
