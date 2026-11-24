import CoreGraphics
import Testing
@testable import YSkitchCore

struct StatusTextTests {
    @Test func sizeAt2x() {
        #expect(StatusText.size(canvas: CGSize(width: 1440, height: 900), scale: 2) == "2880×1800 px · 1440×900 pt")
    }

    @Test func sizeAt1x() {
        #expect(StatusText.size(canvas: CGSize(width: 100, height: 50), scale: 1) == "100×50 px · 100×50 pt")
    }

    @Test func sizeAtFractionalScale() {
        #expect(StatusText.size(canvas: CGSize(width: 101, height: 51), scale: 1.5) == "152×77 px · 101×51 pt")
    }

    @Test func scale() {
        #expect(StatusText.scale(1) == "@1x")
        #expect(StatusText.scale(3) == "@3x")
        #expect(StatusText.scale(1.5) == "@1.5x")
    }

    @Test func zoomRounds() {
        #expect(StatusText.zoom(1) == "100%")
        #expect(StatusText.zoom(0.333) == "33%")
        #expect(StatusText.zoom(0.667) == "67%")
        #expect(StatusText.zoom(24) == "2400%")
    }

    @Test func pixelCountMatchesFlattenedImageAtScale3() {
        for n in 1...200 {
            var document = Document(blankSize: CGSize(width: 1, height: 1), scale: 3)
            document.applyCrop(CGRect(x: -50.0 / 3, y: 0, width: CGFloat(n) / 3, height: 1))
            let canvas = document.canvasRect
            let text = StatusText.size(canvas: canvas.size, scale: 3)
            let pixelWidth = Int(text.split(separator: "×")[0])
            #expect(pixelWidth == Renderer.flatten(document).width, "n=\(n)")
        }
    }

    // MARK: - Geometry

    private func annotation(_ shape: AnnotationShape, thickness: CGFloat = 4) -> Annotation {
        Annotation(style: AnnotationStyle(color: RGBAColor(red: 1, green: 0, blue: 0), thickness: thickness), shape: shape)
    }

    private func text(_ shape: AnnotationShape, thickness: CGFloat = 4, origin: CGPoint = .zero, scale: CGFloat = 1) -> String {
        StatusText.geometry(StatusGeometry(annotation(shape, thickness: thickness)), canvasOrigin: origin, scale: scale)
    }

    @Test func arrowPointingRight() {
        let shape = AnnotationShape.arrow(tail: CGPoint(x: 10, y: 20), head: CGPoint(x: 110, y: 20))
        #expect(text(shape) == "Arrow · (10, 20) → (110, 20) · 100 px · 0° · 4 pt")
    }

    @Test func angleIsCounterClockwiseOnScreen() {
        let origin = CGPoint(x: 50, y: 50)
        func angle(to end: CGPoint) -> String {
            String(text(.line(start: origin, end: end)).split(separator: " · ")[3])
        }
        #expect(angle(to: CGPoint(x: 50, y: 0)) == "90°")
        #expect(angle(to: CGPoint(x: 50, y: 100)) == "-90°")
        #expect(angle(to: CGPoint(x: 0, y: 50)) == "180°")
        #expect(angle(to: CGPoint(x: 100, y: 0)) == "45°")
        #expect(angle(to: CGPoint(x: 0, y: 100)) == "-135°")
        #expect(angle(to: CGPoint(x: 0, y: 50.001)) == "180°")
    }

    @Test func lineAtScale2WithFractionalThickness() {
        let shape = AnnotationShape.line(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 30, y: 40))
        #expect(text(shape, thickness: 4.5, scale: 2) == "Line · (0, 0) → (60, 80) · 100 px · -53° · 4.5 pt")
    }

    @Test func rectangleKinds() {
        let rect = CGRect(x: 10, y: 20, width: 50, height: 30)
        #expect(text(.rectangle(rect)) == "Rectangle · (10, 20) → (60, 50) · 50×30 px · 4 pt")
        #expect(text(.roundedRectangle(rect)) == "Rounded Rectangle · (10, 20) → (60, 50) · 50×30 px · 4 pt")
        #expect(text(.ellipse(rect)) == "Ellipse · (10, 20) → (60, 50) · 50×30 px · 4 pt")
        #expect(text(.pixelate(rect), thickness: 10) == "Pixelate · (10, 20) → (60, 50) · 50×30 px · 10 pt")
    }

    @Test func coordinatesAreRelativeToCanvasOriginAndCanBeNegative() {
        let rect = CGRect(x: 10, y: 20, width: 50, height: 30)
        #expect(text(.rectangle(rect), origin: CGPoint(x: 30, y: 40), scale: 2)
            == "Rectangle · (-40, -40) → (60, 20) · 100×60 px · 4 pt")
    }

    @Test func pixelsRoundAndSizeMatchesCorners() {
        let rect = CGRect(x: 0.3, y: 0.2, width: 10.4, height: 5.4)
        #expect(text(.rectangle(rect), scale: 1) == "Rectangle · (0, 0) → (11, 6) · 11×6 px · 4 pt")
    }

    @Test func freehandUsesPointsBounds() {
        let points = [CGPoint(x: 30, y: 10), CGPoint(x: 5, y: 40), CGPoint(x: 20, y: 25)]
        #expect(text(.pen(points: points)) == "Pen · (5, 10) → (30, 40) · 25×30 px · 4 pt")
        #expect(text(.highlighter(points: points), thickness: 20) == "Highlighter · (5, 10) → (30, 40) · 25×30 px · 20 pt")
    }

    @Test func textUsesLayoutBoxAndFontSize() {
        let content = TextContent(origin: CGPoint(x: 10, y: 20), string: "Hi")
        let size = TextLayout.layout(string: "Hi", fontSize: 24).size
        let w = Int((10 + size.width).rounded()) - 10
        let h = Int((20 + size.height).rounded()) - 20
        #expect(text(.text(content), thickness: 24) == "Text · (10, 20) → (\(10 + w), \(20 + h)) · \(w)×\(h) px · 24 pt")
    }

    @Test func boxWithoutThickness() {
        let geometry = StatusGeometry.box(rect: CGRect(x: 0, y: 0, width: 200, height: 100), name: "Crop", thickness: nil)
        #expect(StatusText.geometry(geometry, canvasOrigin: .zero, scale: 2) == "Crop · (0, 0) → (400, 200) · 400×200 px")
    }

    @Test func boxFromDragStartToCurrentCorner() {
        let geometry = StatusGeometry.box(
            name: "Rectangle", from: CGPoint(x: 60, y: 50), to: CGPoint(x: 10, y: 20), thickness: 4)
        #expect(StatusText.geometry(geometry, canvasOrigin: .zero, scale: 1) == "Rectangle · (60, 50) → (10, 20) · 50×30 px · 4 pt")
    }

    @Test func multipleSelectionUnionsGeometryBounds() throws {
        let annotations = [
            annotation(.rectangle(CGRect(x: 10, y: 20, width: 50, height: 30))),
            annotation(.line(start: CGPoint(x: 100, y: 5), end: CGPoint(x: 80, y: 40)), thickness: 20),
            annotation(.pen(points: [CGPoint(x: 0, y: 30), CGPoint(x: 5, y: 35)])),
        ]
        let geometry = try #require(StatusGeometry(selection: annotations))
        #expect(StatusText.geometry(geometry, canvasOrigin: .zero, scale: 1) == "3 objects · (0, 5) → (100, 50) · 100×45 px")
    }

    @Test func selectionOfOneOrNone() {
        let line = annotation(.line(start: .zero, end: CGPoint(x: 10, y: 0)))
        #expect(StatusGeometry(selection: []) == nil)
        #expect(StatusGeometry(selection: [line]) == StatusGeometry(line))
    }
}

struct ThicknessStatusTests {
    @Test func meaningPerTool() {
        #expect(StatusText.thickness(tool: .arrow, value: 12) == "Arrow · Width 12 pt")
        #expect(StatusText.thickness(tool: .highlighter, value: 20) == "Highlighter · Width 20 pt")
        #expect(StatusText.thickness(tool: .text, value: 36) == "Text · Font size 36 pt")
        #expect(StatusText.thickness(tool: .pixelate, value: 10) == "Pixelate · Block size 10 pt")
        #expect(StatusText.thickness(tool: .pen, value: 4.5) == "Pen · Width 4.5 pt")
        #expect(StatusText.thickness(tool: .select, value: 4) == nil)
        #expect(StatusText.thickness(tool: .crop, value: 4) == nil)
    }
}
