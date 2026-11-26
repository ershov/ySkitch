import CoreGraphics
import Testing
@testable import YSkitchCore

private let editRed = RGBAColor(hex: 0xFF2500)
private let editBlue = RGBAColor(hex: 0x198EFE)

private func annotation(_ shape: AnnotationShape, thickness: CGFloat = 4) -> Annotation {
    Annotation(style: AnnotationStyle(color: editRed, thickness: thickness), shape: shape)
}

@Suite struct HitTestTests {
    let rect = CGRect(x: 10, y: 10, width: 100, height: 80)

    private func hit(_ a: Annotation, _ x: CGFloat, _ y: CGFloat, tolerance: CGFloat = 1) -> Bool {
        AnnotationHitTest.contains(a, point: CGPoint(x: x, y: y), tolerance: tolerance)
    }

    @Test func outlineShapesHitOnStrokeOnly() {
        for shape: AnnotationShape in [.rectangle(rect), .roundedRectangle(rect)] {
            let a = annotation(shape)
            #expect(hit(a, 10, 50), "\(shape)")
            #expect(hit(a, 12.5, 50), "\(shape)")
            #expect(!hit(a, 14, 50), "\(shape)")
            #expect(!hit(a, 60, 50), "\(shape)")
            #expect(!hit(a, 5, 50), "\(shape)")
        }
        let ellipse = annotation(.ellipse(rect))
        #expect(hit(ellipse, 10, 50))
        #expect(!hit(ellipse, 60, 50))
        #expect(!hit(ellipse, 12, 12))
    }

    @Test func linesAndFreehandHitNearStroke() {
        let a = CGPoint(x: 10, y: 10), b = CGPoint(x: 110, y: 10)
        for shape: AnnotationShape in [.line(start: a, end: b), .pen(points: [a, CGPoint(x: 60, y: 10), b])] {
            let line = annotation(shape)
            #expect(hit(line, 60, 12.9), "\(shape)")
            #expect(!hit(line, 60, 13.1), "\(shape)")
            #expect(hit(line, 60, 13.1, tolerance: 2), "\(shape)")
        }
        let highlighter = annotation(.highlighter(points: [a, b]), thickness: 20)
        #expect(hit(highlighter, 60, 20))
        #expect(!hit(highlighter, 60, 22))
    }

    @Test func arrowHitInsideOrNear() {
        let arrow = annotation(.arrow(tail: CGPoint(x: 0, y: 0), head: CGPoint(x: 100, y: 0)))
        #expect(hit(arrow, 50, 0, tolerance: 0))
        #expect(hit(arrow, 99, 0, tolerance: 0))
        #expect(!hit(arrow, 50, 5, tolerance: 0))
        #expect(hit(arrow, 50, 5, tolerance: 4))
        #expect(!hit(arrow, 50, 20, tolerance: 4))
    }

    @Test func textHitAnywhereInBounds() throws {
        let content = TextContent(origin: CGPoint(x: 10, y: 10), string: "I I")
        let text = annotation(.text(content), thickness: 40)
        let bounds = text.bounds
        #expect(hit(text, bounds.midX, bounds.midY, tolerance: 0))
        #expect(hit(text, bounds.minX + 0.5, bounds.minY + 0.5, tolerance: 0))
        #expect(!hit(text, bounds.minX - 1.5, bounds.midY, tolerance: 0))
        #expect(hit(text, bounds.minX - 1.5, bounds.midY, tolerance: 2))
        #expect(!hit(text, bounds.maxX + 3, bounds.midY, tolerance: 2))
        #expect(!hit(annotation(.text(TextContent(origin: .zero, string: ""))), 50, 50, tolerance: 4))
    }

    @Test func pixelateHitInsideRect() {
        let pixelate = annotation(.pixelate(rect), thickness: 10)
        #expect(hit(pixelate, 60, 50, tolerance: 0))
        #expect(!hit(pixelate, 5, 50, tolerance: 0))
    }

    @Test func intersectsDrawnGeometryNotBounds() {
        func touches(_ a: Annotation, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Bool {
            AnnotationHitTest.intersects(a, rect: CGRect(x: x, y: y, width: w, height: h))
        }
        let arrow = annotation(.arrow(tail: CGPoint(x: 0, y: 0), head: CGPoint(x: 100, y: 100)))
        #expect(arrow.renderBounds.intersects(CGRect(x: 80, y: 0, width: 15, height: 15)))
        #expect(!touches(arrow, 80, 0, 15, 15))
        #expect(touches(arrow, 40, 40, 20, 20))
        #expect(touches(arrow, -10, -10, 200, 200))

        let outline = annotation(.rectangle(rect))
        #expect(!touches(outline, 40, 40, 20, 20))
        #expect(!touches(outline, 0, 40, 7.5, 10))
        #expect(touches(outline, 0, 40, 8.5, 10))
        #expect(touches(outline, 0, 0, 200, 200))

        let line = annotation(.line(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 100)), thickness: 10)
        #expect(!touches(line, 80, 0, 15, 15))
        #expect(touches(line, 52, 46, 2, 2))

        let pixelate = annotation(.pixelate(rect))
        #expect(touches(pixelate, 40, 40, 20, 20))
        #expect(!touches(pixelate, 0, 0, 5, 5))

        let text = annotation(.text(TextContent(origin: CGPoint(x: 10, y: 10), string: "I I")), thickness: 40)
        #expect(touches(text, text.bounds.midX, text.bounds.midY, 1, 1))
        #expect(!touches(text, text.bounds.maxX + 1, text.bounds.midY, 5, 5))
    }

    @Test func topmostIsLastInDrawingOrder() {
        var document = Document(blankSize: CGSize(width: 200, height: 200), scale: 1)
        let bottom = annotation(.pixelate(CGRect(x: 0, y: 0, width: 100, height: 100)))
        let top = annotation(.pixelate(CGRect(x: 50, y: 50, width: 100, height: 100)))
        document.annotations = [bottom, top]
        #expect(AnnotationHitTest.topmost(in: document, at: CGPoint(x: 75, y: 75), tolerance: 0) == top.id)
        #expect(AnnotationHitTest.topmost(in: document, at: CGPoint(x: 25, y: 25), tolerance: 0) == bottom.id)
        #expect(AnnotationHitTest.topmost(in: document, at: CGPoint(x: 190, y: 10), tolerance: 0) == nil)
    }

    @Test func visualOrderStacksLayers() {
        var document = Document(blankSize: CGSize(width: 200, height: 200), scale: 1)
        let line = annotation(.line(start: .zero, end: CGPoint(x: 10, y: 10)))
        let pixelate1 = annotation(.pixelate(rect))
        let highlight1 = annotation(.highlighter(points: [CGPoint(x: 5, y: 5)]))
        let text = annotation(.text(TextContent(origin: .zero, string: "a")))
        let pixelate2 = annotation(.pixelate(rect))
        let highlight2 = annotation(.highlighter(points: [CGPoint(x: 6, y: 6)]))
        document.annotations = [line, pixelate1, highlight1, text, pixelate2, highlight2]
        #expect(document.annotationsInVisualOrder.map(\.id) == [
            pixelate1.id, pixelate2.id, highlight1.id, highlight2.id, line.id, text.id,
        ])
    }

    @Test func topmostFollowsVisualOrder() {
        var document = Document(blankSize: CGSize(width: 200, height: 200), scale: 1)
        let arrow = annotation(.arrow(tail: CGPoint(x: 20, y: 50), head: CGPoint(x: 120, y: 50)), thickness: 10)
        let highlight = annotation(.highlighter(points: [CGPoint(x: 60, y: 20), CGPoint(x: 60, y: 80)]), thickness: 10)
        let pixelate = annotation(.pixelate(CGRect(x: 0, y: 0, width: 150, height: 100)))
        document.annotations = [arrow, highlight, pixelate]
        #expect(AnnotationHitTest.topmost(in: document, at: CGPoint(x: 60, y: 50), tolerance: 0) == arrow.id)
        #expect(AnnotationHitTest.topmost(in: document, at: CGPoint(x: 60, y: 30), tolerance: 0) == highlight.id)
        #expect(AnnotationHitTest.topmost(in: document, at: CGPoint(x: 140, y: 90), tolerance: 0) == pixelate.id)
    }
}

@Suite struct GeometryEditTests {
    let delta = CGVector(dx: 5, dy: -3)
    let rect = CGRect(x: 10, y: 20, width: 30, height: 40)

    @Test func translatedMovesEveryShape() {
        let moved = rect.offsetBy(dx: 5, dy: -3)
        let p = CGPoint(x: 1, y: 2), q = CGPoint(x: 11, y: 12)
        let p2 = CGPoint(x: 6, y: -1), q2 = CGPoint(x: 16, y: 9)
        let cases: [(AnnotationShape, AnnotationShape)] = [
            (.rectangle(rect), .rectangle(moved)),
            (.roundedRectangle(rect), .roundedRectangle(moved)),
            (.ellipse(rect), .ellipse(moved)),
            (.pixelate(rect), .pixelate(moved)),
            (.line(start: p, end: q), .line(start: p2, end: q2)),
            (.arrow(tail: p, head: q), .arrow(tail: p2, head: q2)),
            (.pen(points: [p, q]), .pen(points: [p2, q2])),
            (.highlighter(points: [p, q]), .highlighter(points: [p2, q2])),
            (.text(TextContent(origin: p, string: "A")), .text(TextContent(origin: p2, string: "A"))),
        ]
        for (shape, expected) in cases {
            let original = annotation(shape)
            let result = original.translated(by: delta)
            #expect(result.shape == expected)
            #expect(result.id == original.id)
            #expect(result.style == original.style)
        }
    }

    @Test func resizedMapsGeometryOntoNewBounds() {
        let target = CGRect(x: 0, y: 0, width: 60, height: 20)
        for shape: AnnotationShape in [.rectangle(rect), .roundedRectangle(rect), .ellipse(rect), .pixelate(rect)] {
            #expect(annotation(shape).resized(to: target).bounds == target)
        }
        let line = annotation(.line(start: CGPoint(x: 10, y: 60), end: CGPoint(x: 40, y: 20))).resized(to: target)
        #expect(line.shape == .line(start: CGPoint(x: 0, y: 20), end: CGPoint(x: 60, y: 0)))
        let arrow = annotation(.arrow(tail: CGPoint(x: 10, y: 20), head: CGPoint(x: 40, y: 60))).resized(to: target)
        #expect(arrow.shape == .arrow(tail: .zero, head: CGPoint(x: 60, y: 20)))
        let pen = annotation(.pen(points: [CGPoint(x: 10, y: 20), CGPoint(x: 25, y: 40), CGPoint(x: 40, y: 60)]))
        #expect(pen.resized(to: target).shape
            == .pen(points: [.zero, CGPoint(x: 30, y: 10), CGPoint(x: 60, y: 20)]))
        let highlighter = annotation(.highlighter(points: [CGPoint(x: 10, y: 20), CGPoint(x: 40, y: 60)]))
        #expect(highlighter.resized(to: target).bounds == target)
        let text = annotation(.text(TextContent(origin: .zero, string: "A")))
        #expect(text.resized(to: target) == text)
    }

    @Test func resizedMirrorsPointsOnFlippedAxes() {
        let stroke = annotation(.pen(points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 5), CGPoint(x: 20, y: 0)]))
        let mirroredX = stroke.resized(to: CGRect(x: -20, y: 0, width: 20, height: 5), flippedX: true)
        #expect(mirroredX.shape == .pen(points: [CGPoint(x: 0, y: 0), CGPoint(x: -10, y: 5), CGPoint(x: -20, y: 0)]))
        let mirroredY = stroke.resized(to: CGRect(x: 0, y: -5, width: 20, height: 5), flippedY: true)
        #expect(mirroredY.shape == .pen(points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: -5), CGPoint(x: 20, y: 0)]))
        let plain = stroke.resized(to: CGRect(x: 0, y: 0, width: 40, height: 5))
        #expect(plain.shape == .pen(points: [CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 5), CGPoint(x: 40, y: 0)]))
    }

    @Test func resizingZeroWidthStrokePastFixedSideStaysFinite() {
        let stroke = annotation(.pen(points: [CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 5), CGPoint(x: 10, y: 20)]))
        for handle in [BoundsHandle.left, .right] {
            let result = ResizeMath.resize(original: stroke.bounds, dragging: handle, to: CGPoint(x: 0, y: 0))
            guard case .pen(let points) = stroke.resized(
                to: result.rect, flippedX: result.flippedX, flippedY: result.flippedY).shape
            else { Issue.record("not a pen"); continue }
            #expect(points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            #expect(Set(points.map(\.x)) == [handle == .right ? 10 : 0])
        }
    }

    @Test func withEndpointMovesOneEnd() {
        let a = CGPoint(x: 1, y: 2), b = CGPoint(x: 30, y: 40), c = CGPoint(x: 7, y: 8)
        let line = annotation(.line(start: a, end: b))
        #expect(line.withEndpoint(.start, at: c).shape == .line(start: c, end: b))
        #expect(line.withEndpoint(.end, at: c).shape == .line(start: a, end: c))
        let arrow = annotation(.arrow(tail: a, head: b))
        #expect(arrow.withEndpoint(.tail, at: c).shape == .arrow(tail: c, head: b))
        #expect(arrow.withEndpoint(.head, at: c).shape == .arrow(tail: a, head: c))
        #expect(arrow.endpoint(.head) == b)
        let rectangle = annotation(.rectangle(rect))
        #expect(rectangle.withEndpoint(.start, at: c) == rectangle)
        #expect(rectangle.endpoint(.start) == nil)
    }

    @Test func withStyleHonorsKind() {
        let rectangle = annotation(.rectangle(rect)).withStyle(color: editBlue, thickness: 12)
        #expect(rectangle.style == AnnotationStyle(color: editBlue, thickness: 12))
        #expect(annotation(.rectangle(rect)).withStyle(thickness: 500).style.thickness == Tool.strokeRange.upperBound)

        let pixelate = annotation(.pixelate(rect), thickness: 10).withStyle(color: editBlue, thickness: 20)
        #expect(pixelate.style == AnnotationStyle(color: editRed, thickness: 20))

        let text = annotation(.text(TextContent(origin: .zero, string: "A")), thickness: 24)
        #expect(text.withStyle(thickness: 48).style.thickness == 48)
        #expect(text.withStyle(thickness: 2).style.thickness == Tool.fontSizeRange.lowerBound)
        #expect(text.withStyle(color: editBlue).style.color == editBlue)
    }

    @Test func shapeTool() {
        #expect(AnnotationShape.rectangle(rect).tool == .rectangle)
        #expect(AnnotationShape.arrow(tail: .zero, head: .zero).tool == .arrow)
        #expect(AnnotationShape.highlighter(points: []).tool == .highlighter)
        #expect(AnnotationShape.text(TextContent(origin: .zero, string: "")).tool == .text)
        #expect(AnnotationShape.pixelate(rect).tool == .pixelate)
    }
}

@Suite struct HandleTests {
    let rect = CGRect(x: 10, y: 20, width: 30, height: 40)

    @Test func handleCountPerKind() {
        let p = CGPoint(x: 1, y: 2), q = CGPoint(x: 3, y: 4)
        let cases: [(AnnotationShape, Int)] = [
            (.rectangle(rect), 8), (.roundedRectangle(rect), 8), (.ellipse(rect), 8), (.pixelate(rect), 8),
            (.pen(points: [p, q]), 2), (.highlighter(points: [p, q]), 2),
            (.pen(points: [p, q, rect.origin]), 8), (.highlighter(points: [p, q, rect.origin]), 8),
            (.line(start: p, end: q), 2), (.arrow(tail: p, head: q), 2),
            (.text(TextContent(origin: p, string: "A")), 0),
        ]
        for (shape, count) in cases {
            #expect(Handles.handles(for: annotation(shape)).count == count, "\(shape)")
        }
    }

    @Test func handlePositions() {
        let handles = Handles.handles(for: annotation(.rectangle(rect)))
        #expect(handles.first == Handle(kind: .bounds(.topLeft), position: CGPoint(x: 10, y: 20)))
        #expect(handles.contains(Handle(kind: .bounds(.right), position: CGPoint(x: 40, y: 40))))
        #expect(handles.contains(Handle(kind: .bounds(.bottomRight), position: CGPoint(x: 40, y: 60))))
        let arrow = Handles.handles(for: annotation(.arrow(tail: .zero, head: CGPoint(x: 5, y: 5))))
        #expect(arrow == [
            Handle(kind: .endpoint(.tail), position: .zero),
            Handle(kind: .endpoint(.head), position: CGPoint(x: 5, y: 5)),
        ])
    }

    @Test func handleAtPoint() {
        let a = annotation(.rectangle(rect))
        #expect(Handles.handle(for: a, at: CGPoint(x: 42, y: 61), radius: 3)?.kind == .bounds(.bottomRight))
        #expect(Handles.handle(for: a, at: CGPoint(x: 25, y: 40), radius: 3) == nil)
        let line = annotation(.line(start: .zero, end: CGPoint(x: 2, y: 0)))
        #expect(Handles.handle(for: line, at: CGPoint(x: 1.5, y: 0), radius: 3)?.kind == .endpoint(.end))
    }
}

@Suite struct ResizeMathTests {
    let rect = CGRect(x: 10, y: 20, width: 30, height: 40)

    private func flips(
        _ handle: BoundsHandle, _ x: CGFloat, _ y: CGFloat, centered: Bool = false, proportional: Bool = false
    ) -> [Bool] {
        let result = ResizeMath.resize(
            original: rect, dragging: handle, to: CGPoint(x: x, y: y), centered: centered, proportional: proportional)
        return [result.flippedX, result.flippedY]
    }

    @Test func flipsWhenDraggedSidePassesTheOppositeOne() {
        #expect(flips(.bottomRight, 50, 70) == [false, false])
        #expect(flips(.bottomRight, 0, 70) == [true, false])
        #expect(flips(.bottomRight, 0, 0) == [true, true])
        #expect(flips(.topLeft, 50, 70) == [true, true])
        #expect(flips(.right, 0, 0) == [true, false])
        #expect(flips(.top, 0, 100) == [false, true])
        #expect(flips(.right, 10, 0) == [false, false])
    }

    @Test func flipsAtTheCenterWhenCentered() {
        #expect(flips(.right, 20, 0, centered: true) == [true, false])
        #expect(flips(.right, 30, 0, centered: true) == [false, false])
        #expect(flips(.bottomRight, 30, 0, centered: true) == [false, true])
    }

    @Test func proportionalFlipsFollowEachFactorSign() {
        #expect(flips(.bottomRight, 0, 70, proportional: true) == [true, false])
        #expect(flips(.bottomRight, 0, 0, proportional: true) == [true, true])
        #expect(flips(.right, 0, 0, proportional: true) == [true, false])
        #expect(flips(.bottom, 0, 0, proportional: true) == [false, true])
    }

    @Test func flipKeepsBoundsNormalized() {
        let result = ResizeMath.resize(original: rect, dragging: .right, to: CGPoint(x: -20, y: 0))
        #expect(result.rect == CGRect(x: -20, y: 20, width: 30, height: 40))
    }

    @Test func cornerMovesKeepingOppositeFixed() {
        #expect(ResizeMath.bounds(original: rect, dragging: .bottomRight, to: CGPoint(x: 50, y: 70))
            == CGRect(x: 10, y: 20, width: 40, height: 50))
        #expect(ResizeMath.bounds(original: rect, dragging: .topLeft, to: CGPoint(x: 0, y: 30))
            == CGRect(x: 0, y: 30, width: 40, height: 30))
    }

    @Test func edgeChangesOneAxis() {
        #expect(ResizeMath.bounds(original: rect, dragging: .top, to: CGPoint(x: 500, y: 0))
            == CGRect(x: 10, y: 0, width: 30, height: 60))
        #expect(ResizeMath.bounds(original: rect, dragging: .right, to: CGPoint(x: 60, y: -100))
            == CGRect(x: 10, y: 20, width: 50, height: 40))
    }

    @Test func flipNormalizes() {
        #expect(ResizeMath.bounds(original: rect, dragging: .left, to: CGPoint(x: 50, y: 0))
            == CGRect(x: 40, y: 20, width: 10, height: 40))
        #expect(ResizeMath.bounds(original: rect, dragging: .bottomRight, to: CGPoint(x: 0, y: 0))
            == CGRect(x: 0, y: 0, width: 10, height: 20))
    }

    @Test func minimumSize() {
        let collapsed = ResizeMath.bounds(original: rect, dragging: .bottomRight, to: CGPoint(x: 10, y: 20.5))
        #expect(collapsed == CGRect(x: 10, y: 20, width: 1, height: 1))
        let flipped = ResizeMath.bounds(original: rect, dragging: .right, to: CGPoint(x: 9.5, y: 0))
        #expect(flipped == CGRect(x: 9, y: 20, width: 1, height: 40))
    }
}

@Suite struct CenteredResizeTests {
    let rect = CGRect(x: 10, y: 20, width: 30, height: 40)

    private func center(_ r: CGRect) -> CGPoint { CGPoint(x: r.midX, y: r.midY) }

    @Test(arguments: BoundsHandle.allCases)
    func everyHandleKeepsCenter(handle: BoundsHandle) {
        let result = ResizeMath.bounds(original: rect, dragging: handle, to: CGPoint(x: 80, y: 90), centered: true)
        #expect(center(result) == center(rect))
    }

    @Test func cornerAndEdgeExtents() {
        #expect(ResizeMath.bounds(original: rect, dragging: .bottomRight, to: CGPoint(x: 50, y: 70), centered: true)
            == CGRect(x: 0, y: 10, width: 50, height: 60))
        #expect(ResizeMath.bounds(original: rect, dragging: .top, to: CGPoint(x: 500, y: 0), centered: true)
            == CGRect(x: 10, y: 0, width: 30, height: 80))
        #expect(ResizeMath.bounds(original: rect, dragging: .left, to: CGPoint(x: -500, y: 0), centered: true)
            == CGRect(x: -500, y: 20, width: 1050, height: 40))
    }

    @Test func flippingThroughCenterNormalizes() {
        #expect(ResizeMath.bounds(original: rect, dragging: .left, to: CGPoint(x: 60, y: 0), centered: true)
            == CGRect(x: -10, y: 20, width: 70, height: 40))
    }

    @Test func minimumSize() {
        let result = ResizeMath.bounds(original: rect, dragging: .bottomRight, to: CGPoint(x: 25, y: 40), centered: true)
        #expect(result == CGRect(x: 24.5, y: 39.5, width: 1, height: 1))
    }

    @Test func endpointMirrorsAroundMidpoint() {
        let line = annotation(.line(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 100, y: 40)))
        let moved = line.withEndpointMirrored(.end, at: CGPoint(x: 120, y: 60))
        #expect(moved.shape == .line(start: CGPoint(x: -20, y: -20), end: CGPoint(x: 120, y: 60)))
        let arrow = annotation(.arrow(tail: CGPoint(x: 0, y: 0), head: CGPoint(x: 100, y: 40)))
        #expect(arrow.withEndpointMirrored(.start, at: CGPoint(x: 10, y: 10)).shape
            == .arrow(tail: CGPoint(x: 10, y: 10), head: CGPoint(x: 90, y: 30)))
        let box = annotation(.rectangle(rect))
        #expect(box.withEndpointMirrored(.end, at: .zero) == box)
    }

    @Test func dotStretchesSymmetrically() {
        let dot = annotation(.pen(points: [CGPoint(x: 30, y: 40), CGPoint(x: 30, y: 40)]))
        #expect(dot.stretchedDot(to: CGPoint(x: 40, y: 50), centered: true).shape
            == .pen(points: [CGPoint(x: 20, y: 30), CGPoint(x: 40, y: 50)]))
    }
}

@Suite struct ProportionalResizeTests {
    let rect = CGRect(x: 10, y: 20, width: 30, height: 40)

    @Test func cornerScalesByLargerFactor() {
        #expect(ResizeMath.bounds(original: rect, dragging: .bottomRight, to: CGPoint(x: 70, y: 60), proportional: true)
            == CGRect(x: 10, y: 20, width: 60, height: 80))
        #expect(ResizeMath.bounds(original: rect, dragging: .bottomRight, to: CGPoint(x: 25, y: 120), proportional: true)
            == CGRect(x: 10, y: 20, width: 75, height: 100))
    }

    @Test func cornerWithCenter() {
        #expect(ResizeMath.bounds(
            original: rect, dragging: .bottomRight, to: CGPoint(x: 55, y: 50), centered: true, proportional: true)
            == CGRect(x: -5, y: 0, width: 60, height: 80))
    }

    @Test func cornerFlipKeepsSignPerAxis() {
        #expect(ResizeMath.bounds(original: rect, dragging: .bottomRight, to: CGPoint(x: -20, y: 60), proportional: true)
            == CGRect(x: -20, y: 20, width: 30, height: 40))
        #expect(ResizeMath.bounds(original: rect, dragging: .bottomRight, to: CGPoint(x: -20, y: -20), proportional: true)
            == CGRect(x: -20, y: -20, width: 30, height: 40))
    }

    @Test func edgeScalesOtherAxisAroundCenterLine() {
        #expect(ResizeMath.bounds(original: rect, dragging: .right, to: CGPoint(x: 70, y: 999), proportional: true)
            == CGRect(x: 10, y: 0, width: 60, height: 80))
        #expect(ResizeMath.bounds(original: rect, dragging: .bottom, to: CGPoint(x: 0, y: 100), proportional: true)
            == CGRect(x: -5, y: 20, width: 60, height: 80))
    }

    @Test func edgeWithCenter() {
        #expect(ResizeMath.bounds(
            original: rect, dragging: .right, to: CGPoint(x: 55, y: 0), centered: true, proportional: true)
            == CGRect(x: -5, y: 0, width: 60, height: 80))
    }

    @Test func zeroExtentIgnoresProportional() {
        let dot = CGRect(x: 10, y: 20, width: 0, height: 0)
        let line = CGRect(x: 10, y: 20, width: 0, height: 40)
        for original in [dot, line] {
            let point = CGPoint(x: 50, y: 80)
            #expect(ResizeMath.bounds(original: original, dragging: .bottomRight, to: point, proportional: true)
                == ResizeMath.bounds(original: original, dragging: .bottomRight, to: point))
        }
    }
}

@Suite struct DotTests {
    let location = CGPoint(x: 30, y: 40)

    private func dot(_ tool: Tool = .pen, thickness: CGFloat = 10) -> Annotation {
        annotation(tool == .pen ? .pen(points: [location, location]) : .highlighter(points: [location, location]),
                   thickness: thickness)
    }

    @Test func detectsDots() {
        #expect(dot().dotLocation == location)
        #expect(dot(.highlighter).dotLocation == location)
        #expect(annotation(.pen(points: [location, CGPoint(x: 31, y: 40)])).dotLocation == nil)
        #expect(annotation(.rectangle(CGRect(x: 1, y: 1, width: 0, height: 0))).dotLocation == nil)
    }

    @Test func hasSingleBottomRightHandle() {
        #expect(Handles.handles(for: dot()) == [Handle(kind: .bounds(.bottomRight), position: location)])
        #expect(Handles.handle(for: dot(), at: CGPoint(x: 32, y: 41), radius: 3)?.kind == .bounds(.bottomRight))
    }

    @Test func hitTestUsesThicknessAndTolerance() {
        let a = dot()
        #expect(AnnotationHitTest.contains(a, point: location, tolerance: 1))
        #expect(AnnotationHitTest.contains(a, point: CGPoint(x: 35.5, y: 40), tolerance: 1))
        #expect(!AnnotationHitTest.contains(a, point: CGPoint(x: 37, y: 40), tolerance: 1))
        #expect(AnnotationHitTest.intersects(a, rect: CGRect(x: 33, y: 38, width: 10, height: 4)))
        #expect(!AnnotationHitTest.intersects(a, rect: CGRect(x: 40, y: 38, width: 10, height: 4)))
    }

    @Test func stretchesIntoStraightStroke() {
        let target = CGPoint(x: 10, y: 5)
        #expect(dot().stretchedDot(to: target).shape == .pen(points: [location, target]))
        #expect(dot(.highlighter).stretchedDot(to: target).shape == .highlighter(points: [location, target]))
        let stroke = annotation(.pen(points: [location, CGPoint(x: 50, y: 50)]))
        #expect(stroke.stretchedDot(to: target) == stroke)
    }

    @Test func stretchedDotHasEndpointHandles() {
        let stretched = dot().stretchedDot(to: CGPoint(x: 60, y: 40))
        #expect(Handles.handles(for: stretched).map(\.kind) == [.endpoint(.start), .endpoint(.end)])
    }

    @Test func horizontalStrokeKeepsZeroAxis() {
        let line = annotation(.pen(points: [CGPoint(x: 10, y: 20), CGPoint(x: 50, y: 20)]), thickness: 4)
        let resized = line.resized(to: CGRect(x: 10, y: 20, width: 80, height: 0))
        #expect(resized.shape == .pen(points: [CGPoint(x: 10, y: 20), CGPoint(x: 90, y: 20)]))
    }

    @Test func statusShowsZeroSize() {
        let text = StatusText.geometry(StatusGeometry(dot()), canvasOrigin: .zero, scale: 1)
        #expect(text == "Pen · (30, 40) → (30, 40) · 0×0 px · 10 pt")
    }
}

@Suite struct StraightStrokeTests {
    let a = CGPoint(x: 10, y: 20), b = CGPoint(x: 50, y: 30), c = CGPoint(x: 90, y: 5)

    @Test func indicatorKindPerShape() {
        let rect = CGRect(x: 1, y: 2, width: 30, height: 40)
        #expect(SelectionIndicator(for: annotation(.line(start: a, end: b))) == .segment(start: a, end: b))
        #expect(SelectionIndicator(for: annotation(.arrow(tail: a, head: b))) == .segment(start: a, end: b))
        #expect(SelectionIndicator(for: annotation(.pen(points: [a, b]))) == .segment(start: a, end: b))
        #expect(SelectionIndicator(for: annotation(.highlighter(points: [a, b]))) == .segment(start: a, end: b))
        let freehand = annotation(.pen(points: [a, b, c]))
        #expect(SelectionIndicator(for: freehand) == .boundsAndStroke(freehand.bounds, points: [a, b, c]))
        let dot = annotation(.pen(points: [a, a]))
        #expect(SelectionIndicator(for: dot) == .bounds(dot.bounds))
        #expect(SelectionIndicator(for: annotation(.rectangle(rect))) == .bounds(rect))
        let text = annotation(.text(TextContent(origin: a, string: "A")))
        #expect(SelectionIndicator(for: text) == .bounds(text.bounds))
    }

    @Test func endpointsAndEditing() {
        for make: ([CGPoint]) -> AnnotationShape in [{ .pen(points: $0) }, { .highlighter(points: $0) }] {
            let stroke = annotation(make([a, b]))
            #expect(stroke.isStraightStroke)
            #expect(stroke.endpoint(.start) == a && stroke.endpoint(.end) == b)
            #expect(stroke.withEndpoint(.start, at: c).shape == make([c, b]))
            #expect(stroke.withEndpoint(.end, at: c).shape == make([a, c]))
            let mirrored = stroke.withEndpointMirrored(.end, at: c)
            #expect(mirrored.shape == make([CGPoint(x: -30, y: 45), c]))
        }
    }

    @Test func freehandAndDotAreNotStraight() {
        let freehand = annotation(.pen(points: [a, b, c]))
        #expect(!freehand.isStraightStroke)
        #expect(freehand.endpoint(.start) == nil)
        #expect(freehand.withEndpoint(.start, at: c) == freehand)
        #expect(Handles.handles(for: freehand).count == 8)
        let dot = annotation(.pen(points: [a, a]))
        #expect(!dot.isStraightStroke)
        #expect(dot.endpoint(.end) == nil)
    }
}
