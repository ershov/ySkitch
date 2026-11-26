import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

/// Drawing tools edit the current selection like the Select tool.
@MainActor
struct DrawingToolSelectionTests {
    private static let style = AnnotationStyle(color: RGBAColor(hex: 0xFF2500), thickness: 4)
    private static let rect = CGRect(x: 100, y: 100, width: 80, height: 60)
    private let target = Annotation(style: Self.style, shape: .rectangle(Self.rect))

    private static let tools: [Tool] = [
        .arrow, .line, .rectangle, .roundedRectangle, .ellipse, .pen, .highlighter, .pixelate,
    ]

    private func makeController(tool: Tool, annotations: [Annotation]) -> DocumentWindowController {
        var document = Document(blankSize: CGSize(width: 400, height: 300), scale: 1)
        document.annotations = annotations
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(document: document, title: "Test", toolSettings: settings)
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

    private func click(_ controller: DocumentWindowController, _ point: CGPoint) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, point, in: view))
        view.mouseUp(with: event(.leftMouseUp, point, in: view))
    }

    private func drag(
        _ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint, flags: NSEvent.ModifierFlags = []
    ) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: view, flags: flags))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: view, flags: flags))
        view.mouseUp(with: event(.leftMouseUp, b, in: view, flags: flags))
    }

    private func rightDrag(
        _ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint, flags: NSEvent.ModifierFlags = []
    ) {
        let view = controller.canvasView
        view.rightMouseDown(with: event(.rightMouseDown, a, in: view, flags: flags))
        view.rightMouseDragged(with: event(.rightMouseDragged, b, in: view, flags: flags))
        view.rightMouseUp(with: event(.rightMouseUp, b, in: view, flags: flags))
    }

    /// Click-selects `target` with `tool`.
    private func selectTarget(tool: Tool) -> DocumentWindowController {
        let controller = makeController(tool: tool, annotations: [target])
        click(controller, CGPoint(x: 100, y: 130))
        return controller
    }

    @Test func handleDragResizes() {
        for tool in Self.tools {
            let controller = selectTarget(tool: tool)
            defer { controller.close() }
            let model = controller.model
            drag(controller, from: CGPoint(x: 180, y: 160), to: CGPoint(x: 200, y: 190))
            #expect(model.document.annotations.count == 1, "\(tool)")
            #expect(model.document.annotations.first?.shape
                == .rectangle(CGRect(x: 100, y: 100, width: 100, height: 90)), "\(tool)")
            #expect(controller.selection.selectedIDs == [target.id], "\(tool)")
            #expect(model.undoManager.undoActionName == "Resize", "\(tool)")
            model.undoManager.undo()
            #expect(model.document.annotations == [target], "\(tool)")
            #expect(controller.toolbar.activeTool == tool, "\(tool)")
        }
    }

    @Test func bodyDragMovesSelection() {
        for tool in Self.tools {
            let controller = selectTarget(tool: tool)
            defer { controller.close() }
            let model = controller.model
            drag(controller, from: CGPoint(x: 100, y: 115), to: CGPoint(x: 120, y: 135))
            #expect(model.document.annotations.count == 1, "\(tool)")
            #expect(model.document.annotations.first?.shape
                == .rectangle(Self.rect.offsetBy(dx: 20, dy: 20)), "\(tool)")
            #expect(controller.selection.selectedIDs == [target.id], "\(tool)")
            #expect(model.undoManager.undoActionName == "Move", "\(tool)")
            model.undoManager.undo()
            #expect(model.document.annotations == [target], "\(tool)")
        }
    }

    @Test func shiftBodyDragLocksAxis() {
        let controller = selectTarget(tool: .rectangle)
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 100, y: 115), to: CGPoint(x: 130, y: 125), flags: .shift)
        #expect(controller.model.document.annotations.map(\.shape)
            == [.rectangle(Self.rect.offsetBy(dx: 30, dy: 0))])
    }

    @Test func bodyDragMovesAllSelected() {
        let other = Annotation(style: Self.style, shape: .rectangle(CGRect(x: 20, y: 20, width: 40, height: 30)))
        let controller = makeController(tool: .ellipse, annotations: [target, other])
        defer { controller.close() }
        controller.selection.select([target.id, other.id])
        drag(controller, from: CGPoint(x: 100, y: 130), to: CGPoint(x: 110, y: 135))
        #expect(controller.model.document.annotations.map(\.shape) == [
            .rectangle(Self.rect.offsetBy(dx: 10, dy: 5)),
            .rectangle(CGRect(x: 30, y: 25, width: 40, height: 30)),
        ])
        #expect(controller.model.undoManager.undoActionName == "Move")
    }

    @Test func endpointDragMovesEndpoint() {
        let line = Annotation(
            style: Self.style, shape: .line(start: CGPoint(x: 50, y: 50), end: CGPoint(x: 150, y: 50)))
        for tool in Self.tools {
            let controller = makeController(tool: tool, annotations: [line])
            defer { controller.close() }
            let model = controller.model
            click(controller, CGPoint(x: 100, y: 50))
            #expect(controller.selection.selectedIDs == [line.id], "\(tool)")
            drag(controller, from: CGPoint(x: 150, y: 50), to: CGPoint(x: 150, y: 100))
            #expect(model.document.annotations.map(\.shape)
                == [.line(start: CGPoint(x: 50, y: 50), end: CGPoint(x: 150, y: 100))], "\(tool)")
            #expect(model.undoManager.undoActionName == "Move Endpoint", "\(tool)")
            model.undoManager.undo()
            #expect(model.document.annotations == [line], "\(tool)")
        }
    }

    @Test func dragElsewhereDrawsAndReplacesSelection() {
        for tool in Self.tools {
            let controller = selectTarget(tool: tool)
            defer { controller.close() }
            drag(controller, from: CGPoint(x: 250, y: 200), to: CGPoint(x: 300, y: 250))
            #expect(controller.model.document.annotations.count == 2, "\(tool)")
            #expect(controller.model.document.annotations.first == target, "\(tool)")
            let drawn = controller.model.document.annotations[1]
            let selectsDrawn = tool != .pen && tool != .highlighter
            #expect(controller.selection.selectedIDs == (selectsDrawn ? [drawn.id] : []), "\(tool)")
        }
    }

    @Test func dragOnUnselectedAnnotationDraws() {
        let other = Annotation(style: Self.style, shape: .rectangle(CGRect(x: 20, y: 20, width: 40, height: 30)))
        let controller = makeController(tool: .rectangle, annotations: [target, other])
        defer { controller.close() }
        controller.selection.select([target.id])
        drag(controller, from: CGPoint(x: 20, y: 30), to: CGPoint(x: 70, y: 80))
        let annotations = controller.model.document.annotations
        #expect(annotations.count == 3)
        #expect(Array(annotations.prefix(2)) == [target, other])
        #expect(controller.selection.selectedIDs == [annotations[2].id])
    }

    @Test func clickOnSelectedKeepsSelection() {
        let controller = selectTarget(tool: .pen)
        defer { controller.close() }
        click(controller, CGPoint(x: 100, y: 130))
        #expect(controller.selection.selectedIDs == [target.id])
        #expect(controller.model.document.annotations == [target])
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func clickOnEmptySpaceWithSelectionOnlyClears() {
        let empty = CGPoint(x: 300, y: 250)
        for tool in [Tool.pen, .highlighter] {
            let controller = selectTarget(tool: tool)
            defer { controller.close() }
            click(controller, empty)
            #expect(controller.selection.isEmpty, "\(tool)")
            #expect(controller.model.document.annotations == [target], "\(tool)")
            click(controller, empty)
            #expect(controller.model.document.annotations.count == 2, "\(tool)")
        }
    }

    @Test func escapeCancelsEdit() throws {
        let controller = selectTarget(tool: .arrow)
        defer { controller.close() }
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 180, y: 160), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 220, y: 200), in: view))
        #expect(controller.model.document.annotations.first?.shape != target.shape)
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false,
            keyCode: 53))
        view.keyDown(with: escape)
        #expect(controller.model.document.annotations == [target])
        #expect(!controller.model.isInGesture)
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 220, y: 200), in: view))
        #expect(controller.model.document.annotations == [target])
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func escapeClearsSelectionInEveryTool() throws {
        for tool in [.select, .text] + Self.tools {
            let controller = selectTarget(tool: tool)
            defer { controller.close() }
            #expect(controller.selection.selectedIDs == [target.id])
            let escape = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false,
                keyCode: 53))
            controller.canvasView.keyDown(with: escape)
            #expect(controller.selection.isEmpty, "\(tool)")
            #expect(controller.model.document.annotations == [target])
        }
    }

    @Test func toolbarColorEditsSelection() throws {
        let controller = selectTarget(tool: .highlighter)
        defer { controller.close() }
        let index = try #require(Palette.colors.firstIndex { $0 != Self.style.color })
        controller.toolbar.selectColor(index: index)
        #expect(controller.model.document.annotations.first?.style.color == Palette.colors[index])
    }

    // MARK: - Right/⌃-drag marquee

    private static let marqueeTools: [Tool] = [.select, .text] + tools

    /// `target`, plus `a` and `b` below it; `target` is selected.
    private func marqueeSetup(tool: Tool) -> (DocumentWindowController, Annotation, Annotation) {
        let a = Annotation(style: Self.style, shape: .rectangle(CGRect(x: 20, y: 200, width: 40, height: 30)))
        let b = Annotation(style: Self.style, shape: .ellipse(CGRect(x: 100, y: 200, width: 40, height: 30)))
        let controller = makeController(tool: tool, annotations: [target, a, b])
        controller.selection.select([target.id])
        return (controller, a, b)
    }

    @Test func rightDragAddsTouchedInEveryTool() {
        for tool in Self.marqueeTools {
            let (controller, a, b) = marqueeSetup(tool: tool)
            defer { controller.close() }
            rightDrag(controller, from: CGPoint(x: 10, y: 190), to: CGPoint(x: 150, y: 210))
            #expect(controller.selection.selectedIDs == [target.id, a.id, b.id], "\(tool)")
            #expect(controller.model.document.annotations.count == 3, "\(tool)")
            #expect(!controller.model.undoManager.canUndo, "\(tool)")
            #expect(controller.toolbar.activeTool == tool, "\(tool)")
        }
    }

    @Test func optionRightDragRemovesTouched() {
        let (controller, a, b) = marqueeSetup(tool: .arrow)
        defer { controller.close() }
        controller.selection.select([a.id, target.id, b.id])
        rightDrag(controller, from: CGPoint(x: 10, y: 190), to: CGPoint(x: 70, y: 240), flags: .option)
        #expect(controller.selection.selectedIDs == [target.id, b.id])
    }

    @Test func controlDragActsLikeRightDrag() {
        for tool in Self.marqueeTools {
            let (controller, a, b) = marqueeSetup(tool: tool)
            defer { controller.close() }
            drag(controller, from: CGPoint(x: 10, y: 190), to: CGPoint(x: 150, y: 210), flags: .control)
            #expect(controller.selection.selectedIDs == [target.id, a.id, b.id], "\(tool)")
            #expect(controller.model.document.annotations.count == 3, "\(tool)")
            drag(controller, from: CGPoint(x: 90, y: 190), to: CGPoint(x: 190, y: 210), flags: [.control, .option])
            #expect(controller.selection.selectedIDs == [target.id, a.id], "\(tool)")
        }
    }

    @Test func marqueeTouchesDrawnGeometryOnly() {
        let arrow = Annotation(
            style: Self.style, shape: .arrow(tail: CGPoint(x: 200, y: 50), head: CGPoint(x: 300, y: 150)))
        let controller = makeController(tool: .rectangle, annotations: [arrow])
        defer { controller.close() }
        rightDrag(controller, from: CGPoint(x: 280, y: 40), to: CGPoint(x: 310, y: 60))
        #expect(controller.selection.isEmpty)
        rightDrag(controller, from: CGPoint(x: 240, y: 80), to: CGPoint(x: 260, y: 100))
        #expect(controller.selection.selectedIDs == [arrow.id])
    }

    @Test func rightClickWithoutDragChangesNothing() {
        let (controller, _, _) = marqueeSetup(tool: .pen)
        defer { controller.close() }
        let view = controller.canvasView
        view.rightMouseDown(with: event(.rightMouseDown, CGPoint(x: 300, y: 50), in: view))
        view.rightMouseUp(with: event(.rightMouseUp, CGPoint(x: 300, y: 50), in: view))
        click(controller, CGPoint(x: 100, y: 130))
        let point = CGPoint(x: 300, y: 50)
        view.mouseDown(with: event(.leftMouseDown, point, in: view, flags: .control))
        view.mouseUp(with: event(.leftMouseUp, point, in: view, flags: .control))
        #expect(controller.selection.selectedIDs == [target.id])
        #expect(controller.model.document.annotations.count == 3)
    }

    @Test func marqueeShowsStatusAndEscapeCancels() throws {
        let (controller, _, _) = marqueeSetup(tool: .line)
        defer { controller.close() }
        let view = controller.canvasView
        view.rightMouseDown(with: event(.rightMouseDown, CGPoint(x: 10, y: 190), in: view))
        view.rightMouseDragged(with: event(.rightMouseDragged, CGPoint(x: 150, y: 210), in: view))
        #expect(controller.statusBar.infoLabel.stringValue == "Select · (10, 190) → (150, 210) · 140×20 px")
        #expect(controller.selection.selectedIDs.count == 3)
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false,
            keyCode: 53))
        view.keyDown(with: escape)
        #expect(controller.selection.selectedIDs == [target.id])
        view.rightMouseUp(with: event(.rightMouseUp, CGPoint(x: 150, y: 210), in: view))
        #expect(controller.selection.selectedIDs == [target.id])
    }

    @Test func marqueeBlockedInCropSessionAndTextEditing() {
        let (crop, _, _) = marqueeSetup(tool: .crop)
        defer { crop.close() }
        #expect(crop.canvasView.isCropping)
        rightDrag(crop, from: CGPoint(x: 10, y: 190), to: CGPoint(x: 150, y: 210))
        #expect(crop.selection.selectedIDs == [target.id])

        let (text, _, _) = marqueeSetup(tool: .text)
        defer { text.close() }
        click(text, CGPoint(x: 300, y: 50))
        #expect(text.canvasView.textEditor.isEditing)
        let selected = text.selection.selectedIDs
        rightDrag(text, from: CGPoint(x: 10, y: 190), to: CGPoint(x: 150, y: 210))
        #expect(text.selection.selectedIDs == selected)
        #expect(text.canvasView.textEditor.isEditing)
    }
}

@MainActor
struct DotDrawingTests {
    private func makeController(tool: Tool, annotations: [Annotation] = []) -> DocumentWindowController {
        var document = Document(blankSize: CGSize(width: 400, height: 300), scale: 1)
        document.annotations = annotations
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

    private func click(_ controller: DocumentWindowController, _ point: CGPoint, jitter: CGPoint? = nil) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, point, in: view))
        if let jitter { view.mouseDragged(with: event(.leftMouseDragged, jitter, in: view)) }
        view.mouseUp(with: event(.leftMouseUp, jitter ?? point, in: view))
    }

    private func drag(_ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: view))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: view))
        view.mouseUp(with: event(.leftMouseUp, b, in: view))
    }

    @Test func clickOnEmptySpaceCreatesDot() {
        for (tool, name) in [(Tool.pen, "Draw"), (.highlighter, "Highlight")] {
            let controller = makeController(tool: tool)
            defer { controller.close() }
            let model = controller.model
            click(controller, CGPoint(x: 50, y: 60), jitter: CGPoint(x: 50.5, y: 60.5))
            #expect(model.document.annotations.count == 1, "\(tool)")
            let point = CGPoint(x: 50, y: 60)
            let expected: AnnotationShape = tool == .pen
                ? .pen(points: [point, point]) : .highlighter(points: [point, point])
            #expect(model.document.annotations.first?.shape == expected, "\(tool)")
            #expect(controller.selection.selectedIDs.isEmpty, "\(tool)")
            #expect(model.undoManager.undoActionName == name, "\(tool)")
            model.undoManager.undo()
            #expect(model.document.annotations.isEmpty, "\(tool)")
            #expect(!model.undoManager.canUndo, "\(tool)")
        }
    }

    @Test func clickOnAnnotationSelectsWithoutDot() {
        let target = Annotation(
            style: AnnotationStyle(color: RGBAColor(hex: 0xFF2500), thickness: 4),
            shape: .rectangle(CGRect(x: 100, y: 100, width: 80, height: 60)))
        for tool in [Tool.pen, .highlighter] {
            let controller = makeController(tool: tool, annotations: [target])
            defer { controller.close() }
            click(controller, CGPoint(x: 100, y: 130))
            #expect(controller.model.document.annotations == [target], "\(tool)")
            #expect(controller.selection.selectedIDs == [target.id], "\(tool)")
            #expect(!controller.model.undoManager.canUndo, "\(tool)")
        }
    }

    @Test func draggingDotHandleStretchesIntoLine() {
        let controller = makeController(tool: .pen)
        defer { controller.close() }
        let model = controller.model
        click(controller, CGPoint(x: 50, y: 60))
        let id = model.document.annotations[0].id
        click(controller, CGPoint(x: 50, y: 60))
        #expect(controller.selection.selectedIDs == [id])
        drag(controller, from: CGPoint(x: 50, y: 60), to: CGPoint(x: 120, y: 90))
        #expect(model.document.annotations.count == 1)
        #expect(model.document.annotations[0].shape
            == .pen(points: [CGPoint(x: 50, y: 60), CGPoint(x: 120, y: 90)]))
        #expect(model.undoManager.undoActionName == "Resize")
    }
}

@MainActor
struct StraightStrokeTests {
    private func makeController(tool: Tool) -> DocumentWindowController {
        let document = Document(blankSize: CGSize(width: 400, height: 300), scale: 1)
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(document: document, title: "Test", toolSettings: settings)
        controller.canvasView.toolbar.activeTool = tool
        return controller
    }

    private func mouse(
        _ type: NSEvent.EventType, _ point: CGPoint, flags: NSEvent.ModifierFlags = [], in view: NSView
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: view.convert(point, to: nil), modifierFlags: flags, timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
            pressure: 1)!
    }

    private func flagsChanged(_ flags: NSEvent.ModifierFlags, in view: NSView) -> NSEvent {
        NSEvent.keyEvent(
            with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, characters: "",
            charactersIgnoringModifiers: "", isARepeat: false, keyCode: 56)!
    }

    private func points(_ controller: DocumentWindowController) -> [CGPoint]? {
        switch controller.model.document.annotations.first?.shape {
        case .pen(let points), .highlighter(let points): points
        default: nil
        }
    }

    @Test func shiftFromPressGivesSnappedSegment() {
        for tool in [Tool.pen, .highlighter] {
            let controller = makeController(tool: tool)
            defer { controller.close() }
            let view = controller.canvasView
            let start = CGPoint(x: 100, y: 100)
            view.mouseDown(with: mouse(.leftMouseDown, start, flags: .shift, in: view))
            view.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: 160, y: 110), flags: .shift, in: view))
            view.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: 200, y: 105), flags: .shift, in: view))
            view.mouseUp(with: mouse(.leftMouseUp, CGPoint(x: 200, y: 105), flags: .shift, in: view))
            #expect(points(controller) == [start, CGPoint(x: 200, y: 100)], "\(tool)")
            #expect(controller.model.document.annotations.count == 1, "\(tool)")
        }
    }

    @Test func shiftMidDragStraightensAndStaysStraight() {
        for tool in [Tool.pen, .highlighter] {
            let controller = makeController(tool: tool)
            defer { controller.close() }
            let view = controller.canvasView
            let start = CGPoint(x: 100, y: 100)
            view.mouseDown(with: mouse(.leftMouseDown, start, in: view))
            view.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: 120, y: 140), in: view))
            view.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: 160, y: 110), in: view))
            #expect(points(controller)?.count == 3, "\(tool)")

            view.flagsChanged(with: flagsChanged(.shift, in: view))
            #expect(points(controller) == [start, CGPoint(x: 160, y: 100)], "\(tool)")

            view.flagsChanged(with: flagsChanged([], in: view))
            #expect(points(controller) == [start, CGPoint(x: 160, y: 110)], "\(tool)")

            view.mouseDragged(with: mouse(.leftMouseDragged, CGPoint(x: 170, y: 130), in: view))
            let snapped = Geometry.constrainTo45Degrees(from: start, to: CGPoint(x: 170, y: 130))
            #expect(snapped != CGPoint(x: 170, y: 130))
            #expect(points(controller) == [start, CGPoint(x: 170, y: 130)], "\(tool)")

            view.flagsChanged(with: flagsChanged(.shift, in: view))
            #expect(points(controller) == [start, snapped], "\(tool)")

            view.mouseUp(with: mouse(.leftMouseUp, CGPoint(x: 170, y: 130), flags: .shift, in: view))
            #expect(points(controller) == [start, snapped], "\(tool)")
        }
    }

    @Test func shiftClickWithoutDragGivesDot() {
        let controller = makeController(tool: .pen)
        defer { controller.close() }
        let view = controller.canvasView
        let point = CGPoint(x: 50, y: 60)
        view.mouseDown(with: mouse(.leftMouseDown, point, flags: .shift, in: view))
        view.mouseUp(with: mouse(.leftMouseUp, point, flags: .shift, in: view))
        #expect(points(controller) == [point, point])
    }
}
