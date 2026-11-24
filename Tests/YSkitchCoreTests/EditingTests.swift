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
            (.pen(points: [p, q]), 8), (.highlighter(points: [p, q]), 8),
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
