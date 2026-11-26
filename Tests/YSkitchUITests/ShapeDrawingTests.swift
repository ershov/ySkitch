import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct ShapeDrawingTests {
    private func makeController(tool: Tool) -> DocumentWindowController {
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 400, height: 300), scale: 1),
            title: "Test", toolSettings: settings)
        controller.canvasView.toolbar.activeTool = tool
        return controller
    }

    private func event(
        _ type: NSEvent.EventType, _ point: CGPoint, in view: NSView, flags: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: view.convert(point, to: nil), modifierFlags: flags, timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
            pressure: 1)!
    }

    private func drag(
        _ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint,
        flags: NSEvent.ModifierFlags = []
    ) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: view, flags: flags))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: view, flags: flags))
        view.mouseUp(with: event(.leftMouseUp, b, in: view, flags: flags))
    }

    @Test func dragCreatesRectangle() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 10, y: 20), to: CGPoint(x: 60, y: 50))
        let model = controller.canvasView.model
        let style = controller.canvasView.toolbar.currentStyle
        #expect(model.document.annotations.count == 1)
        let annotation = model.document.annotations[0]
        #expect(annotation.shape == .rectangle(CGRect(x: 10, y: 20, width: 50, height: 30)))
        #expect(annotation.style.color == style.color)
        #expect(annotation.style.thickness == style.thickness)
        #expect(model.undoManager.undoActionName == "Draw Rectangle")
        model.undoManager.undo()
        #expect(model.document.annotations.isEmpty)
        #expect(!model.undoManager.canUndo)
    }

    @Test func pixelateDrag() {
        let controller = makeController(tool: .pixelate)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 10, y: 20), to: CGPoint(x: 60, y: 50))
        let model = controller.canvasView.model
        #expect(model.document.annotations.count == 1)
        let annotation = model.document.annotations[0]
        #expect(annotation.shape == .pixelate(CGRect(x: 10, y: 20, width: 50, height: 30)))
        #expect(annotation.style.thickness == controller.canvasView.toolbar.currentStyle.thickness)
        #expect(model.undoManager.undoActionName == "Pixelate")
    }

    @Test func shiftMakesSquare() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 60, y: 90), flags: .shift)
        #expect(controller.canvasView.model.document.annotations[0].shape
            == .rectangle(CGRect(x: 60, y: 60, width: 40, height: 40)))
    }

    private func flagsChanged(_ flags: NSEvent.ModifierFlags, in view: NSView) -> NSEvent {
        NSEvent.keyEvent(
            with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, characters: "",
            charactersIgnoringModifiers: "", isARepeat: false, keyCode: 58)!
    }

    @Test func optionDrawsFromCenter() {
        let controller = makeController(tool: .ellipse)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 130, y: 80), flags: .option)
        #expect(controller.canvasView.model.document.annotations[0].shape
            == .ellipse(CGRect(x: 70, y: 80, width: 60, height: 40)))
    }

    @Test func optionAndShiftDrawCenteredSquare() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 130, y: 80), flags: [.option, .shift])
        #expect(controller.canvasView.model.document.annotations[0].shape
            == .rectangle(CGRect(x: 70, y: 70, width: 60, height: 60)))
    }

    @Test func togglingOptionMidDragSwitchesMode() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        let view = controller.canvasView
        let start = CGPoint(x: 100, y: 100), end = CGPoint(x: 130, y: 120)
        view.mouseDown(with: event(.leftMouseDown, start, in: view))
        view.mouseDragged(with: event(.leftMouseDragged, end, in: view))
        func shape() -> AnnotationShape { view.model.document.annotations[0].shape }
        #expect(shape() == .rectangle(CGRect(x: 100, y: 100, width: 30, height: 20)))
        view.flagsChanged(with: flagsChanged(.option, in: view))
        #expect(shape() == .rectangle(CGRect(x: 70, y: 80, width: 60, height: 40)))
        view.flagsChanged(with: flagsChanged([], in: view))
        #expect(shape() == .rectangle(CGRect(x: 100, y: 100, width: 30, height: 20)))
        view.mouseUp(with: event(.leftMouseUp, end, in: view))
    }

    @Test func statusShowsCursorCornerAndOpposite() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 100, y: 100), in: view, flags: .option))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 130, y: 80), in: view, flags: .option))
        guard case .box(_, let from, let to, _)? = view.statusGeometry else {
            Issue.record("no status geometry")
            return
        }
        #expect(from == CGPoint(x: 70, y: 120))
        #expect(to == CGPoint(x: 130, y: 80))
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 130, y: 80), in: view))
    }

    @Test func clickWithoutDragCreatesNothing() {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        let view = controller.canvasView
        let point = CGPoint(x: 30, y: 30)
        view.mouseDown(with: event(.leftMouseDown, point, in: view))
        view.mouseUp(with: event(.leftMouseUp, point, in: view))
        #expect(view.model.document.annotations.isEmpty)
        #expect(!view.model.undoManager.canUndo)
    }

    @Test func escapeCancelsDrawing() throws {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 10, y: 10), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 80, y: 80), in: view))
        #expect(view.model.document.annotations.count == 1)
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false,
            keyCode: 53))
        view.keyDown(with: escape)
        #expect(view.model.document.annotations.isEmpty)
        #expect(!view.model.isInGesture)
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 80, y: 80), in: view))
        #expect(view.model.document.annotations.isEmpty)
        #expect(!view.model.undoManager.canUndo)
    }

    @Test func roundedRectangleAndEllipseTools() {
        let rounded = makeController(tool: .roundedRectangle)
        defer { rounded.close() }
        drag(rounded, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 40))
        #expect(rounded.canvasView.model.document.annotations[0].shape
            == .roundedRectangle(CGRect(x: 10, y: 10, width: 40, height: 30)))
        #expect(rounded.canvasView.model.undoManager.undoActionName == "Draw Rounded Rectangle")

        let ellipse = makeController(tool: .ellipse)
        defer { ellipse.close() }
        drag(ellipse, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 40))
        #expect(ellipse.canvasView.model.document.annotations[0].shape
            == .ellipse(CGRect(x: 10, y: 10, width: 40, height: 30)))
        #expect(ellipse.canvasView.model.undoManager.undoActionName == "Draw Ellipse")
    }

    @Test func historyAndPasteBlockedMidDrag() throws {
        let controller = makeController(tool: .rectangle)
        defer { controller.close() }
        let view = controller.canvasView
        let model = view.model
        let pasteboard = NSPasteboard(name: .init("ySkitch.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 40, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        pasteboard.setData(bitmap.representation(using: .png, properties: [:]), forType: .png)
        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 10, y: 20), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 60, y: 50), in: view))
        #expect(model.isInGesture)

        let undo = NSMenuItem(title: "Undo", action: #selector(CanvasView.undo(_:)), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: #selector(CanvasView.redo(_:)), keyEquivalent: "Z")
        let paste = NSMenuItem(title: "Paste", action: #selector(DocumentWindowController.paste(_:)), keyEquivalent: "v")
        #expect(!view.validateMenuItem(undo))
        #expect(!view.validateMenuItem(redo))
        #expect(!controller.validateMenuItem(paste))

        let before = model.document
        view.undo(nil)
        view.redo(nil)
        controller.paste(nil)
        #expect(!controller.paste(from: pasteboard))
        #expect(model.document == before)

        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 60, y: 50), in: view))
        #expect(model.document.annotations.count == 1)
        #expect(view.validateMenuItem(undo))
        view.undo(nil)
        #expect(model.document.annotations.isEmpty)
        #expect(!model.undoManager.canUndo)
        #expect(controller.paste(from: pasteboard))
    }
}

@MainActor
struct LineDrawingTests {
    private func makeController(tool: Tool) -> DocumentWindowController {
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 400, height: 300), scale: 1),
            title: "Test", toolSettings: settings)
        controller.canvasView.toolbar.activeTool = tool
        return controller
    }

    private func event(
        _ type: NSEvent.EventType, _ point: CGPoint, in view: NSView, flags: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: view.convert(point, to: nil), modifierFlags: flags, timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
            pressure: 1)!
    }

    private func drag(
        _ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint,
        flags: NSEvent.ModifierFlags = []
    ) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: view, flags: flags))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: view, flags: flags))
        view.mouseUp(with: event(.leftMouseUp, b, in: view, flags: flags))
    }

    private func shapes(_ controller: DocumentWindowController) -> [AnnotationShape] {
        controller.canvasView.model.document.annotations.map(\.shape)
    }

    @Test func arrowDrag() {
        let controller = makeController(tool: .arrow)
        defer { controller.close() }
        let a = CGPoint(x: 10, y: 20), b = CGPoint(x: 90, y: 60)
        drag(controller, from: a, to: b)
        #expect(shapes(controller) == [.arrow(tail: a, head: b)])
        let model = controller.canvasView.model
        #expect(model.undoManager.undoActionName == "Draw Arrow")
        model.undoManager.undo()
        #expect(model.document.annotations.isEmpty)
        #expect(!model.undoManager.canUndo)
    }

    @Test func optionReversesArrow() {
        let controller = makeController(tool: .arrow)
        defer { controller.close() }
        let a = CGPoint(x: 10, y: 20), b = CGPoint(x: 90, y: 60)
        drag(controller, from: a, to: b, flags: .option)
        #expect(shapes(controller) == [.arrow(tail: b, head: a)])
    }

    @Test func shiftSnapsHorizontal() {
        let controller = makeController(tool: .line)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 10, y: 20), to: CGPoint(x: 100, y: 25), flags: .shift)
        guard case .line(let start, let end) = shapes(controller).first else {
            Issue.record("no line")
            return
        }
        #expect(start == CGPoint(x: 10, y: 20))
        #expect(end.y == 20)
        #expect(end.x > 90)
    }

    @Test func lineDrag() {
        let controller = makeController(tool: .line)
        defer { controller.close() }
        let a = CGPoint(x: 10, y: 20), b = CGPoint(x: 90, y: 60)
        drag(controller, from: a, to: b)
        #expect(shapes(controller) == [.line(start: a, end: b)])
        #expect(controller.canvasView.model.undoManager.undoActionName == "Draw Line")
    }

    @Test func tinyDragCreatesNothing() {
        let controller = makeController(tool: .arrow)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 11, y: 10))
        #expect(shapes(controller).isEmpty)
        #expect(!controller.canvasView.model.undoManager.canUndo)
    }
}

@MainActor
struct FreehandDrawingTests {
    private func makeController(tool: Tool) -> DocumentWindowController {
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 400, height: 300), scale: 1),
            title: "Test", toolSettings: settings)
        controller.canvasView.toolbar.activeTool = tool
        return controller
    }

    private func event(_ type: NSEvent.EventType, _ point: CGPoint, in view: NSView) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: view.convert(point, to: nil), modifierFlags: [], timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
            pressure: 1)!
    }

    private func stroke(_ controller: DocumentWindowController, through points: [CGPoint]) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, points[0], in: view))
        for point in points.dropFirst() { view.mouseDragged(with: event(.leftMouseDragged, point, in: view)) }
        view.mouseUp(with: event(.leftMouseUp, points.last!, in: view))
    }

    @Test func penDragCreatesOneAnnotation() throws {
        let controller = makeController(tool: .pen)
        defer { controller.close() }
        stroke(controller, through: [
            CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 25), CGPoint(x: 50, y: 20), CGPoint(x: 70, y: 60),
        ])
        let model = controller.canvasView.model
        #expect(model.document.annotations.count == 1)
        guard case .pen(let points) = model.document.annotations[0].shape else {
            Issue.record("not a pen annotation")
            return
        }
        #expect(points.count >= 3)
        #expect(model.undoManager.undoActionName == "Draw")
        model.undoManager.undo()
        #expect(model.document.annotations.isEmpty)
        #expect(!model.undoManager.canUndo)
    }

    @Test func highlighterDrag() {
        let controller = makeController(tool: .highlighter)
        defer { controller.close() }
        stroke(controller, through: [CGPoint(x: 10, y: 10), CGPoint(x: 40, y: 30), CGPoint(x: 80, y: 30)])
        let model = controller.canvasView.model
        guard case .highlighter = model.document.annotations.first?.shape else {
            Issue.record("not a highlighter annotation")
            return
        }
        #expect(model.undoManager.undoActionName == "Highlight")
    }
}

@MainActor
struct ClickSelectsTests {
    private let target = Annotation(
        style: AnnotationStyle(color: RGBAColor(hex: 0xFF2500), thickness: 4),
        shape: .rectangle(CGRect(x: 100, y: 100, width: 80, height: 60)))

    private func makeController(tool: Tool) -> DocumentWindowController {
        var document = Document(blankSize: CGSize(width: 400, height: 300), scale: 1)
        document.annotations = [target]
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(document: document, title: "Test", toolSettings: settings)
        controller.canvasView.toolbar.activeTool = tool
        return controller
    }

    private func event(_ type: NSEvent.EventType, _ point: CGPoint, in view: NSView) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: view.convert(point, to: nil), modifierFlags: [], timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
            pressure: 1)!
    }

    private func click(_ controller: DocumentWindowController, _ point: CGPoint) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, point, in: view))
        view.mouseUp(with: event(.leftMouseUp, point, in: view))
    }

    private func drag(_ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: view))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: view))
        view.mouseUp(with: event(.leftMouseUp, b, in: view))
    }

    private static let tools: [Tool] = [
        .arrow, .line, .rectangle, .roundedRectangle, .ellipse, .pen, .highlighter, .pixelate,
    ]

    @Test func clickOnAnnotationSelectsIt() {
        for tool in Self.tools {
            let controller = makeController(tool: tool)
            defer { controller.close() }
            click(controller, CGPoint(x: 100, y: 130))
            #expect(controller.selection.selectedIDs == [target.id], "\(tool)")
            #expect(controller.model.document.annotations == [target], "\(tool)")
            #expect(!controller.model.undoManager.canUndo, "\(tool)")
            #expect(controller.toolbar.activeTool == tool)
        }
    }

    @Test func clickOnEmptySpaceClearsSelection() {
        for tool in Self.tools {
            let controller = makeController(tool: tool)
            defer { controller.close() }
            controller.selection.select([target.id])
            click(controller, CGPoint(x: 300, y: 250))
            #expect(controller.selection.isEmpty, "\(tool)")
            #expect(controller.model.document.annotations == [target], "\(tool)")
            #expect(!controller.model.undoManager.canUndo, "\(tool)")
        }
    }

    @Test func dragSelectsNewShapeAndLeavesStrokesUnselected() {
        for tool in Self.tools {
            let controller = makeController(tool: tool)
            defer { controller.close() }
            click(controller, CGPoint(x: 100, y: 130))
            drag(controller, from: CGPoint(x: 200, y: 200), to: CGPoint(x: 260, y: 250))
            #expect(controller.model.document.annotations.count == 2, "\(tool)")
            #expect(controller.model.document.annotations[0] == target, "\(tool)")
            let drawn = controller.model.document.annotations[1]
            let selectsDrawn = tool != .pen && tool != .highlighter
            #expect(controller.selection.selectedIDs == (selectsDrawn ? [drawn.id] : []), "\(tool)")
        }
    }

    @Test func undoOfDrawingLeavesNoSelection() {
        for tool in [Tool.arrow, .line, .rectangle, .roundedRectangle, .ellipse, .pixelate] {
            let controller = makeController(tool: tool)
            defer { controller.close() }
            drag(controller, from: CGPoint(x: 200, y: 200), to: CGPoint(x: 260, y: 250))
            #expect(controller.selection.selectedIDs.count == 1, "\(tool)")
            controller.model.undoManager.undo()
            #expect(controller.model.document.annotations == [target], "\(tool)")
            #expect(controller.selection.isEmpty, "\(tool)")
        }
    }
}
