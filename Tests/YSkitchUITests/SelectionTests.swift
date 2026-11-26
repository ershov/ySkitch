import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct SelectionTests {
    private static let style = AnnotationStyle(color: RGBAColor(hex: 0xFF2500), thickness: 4)
    private let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))

    private func makeController(_ annotations: [Annotation]) -> DocumentWindowController {
        var document = Document(blankSize: CGSize(width: 400, height: 300), scale: 1)
        document.annotations = annotations
        let controller = DocumentWindowController(document: document, title: "Test", toolSettings: settings)
        controller.toolbar.activeTool = .select
        return controller
    }

    private func rectangle(_ rect: CGRect, extendsCanvas: Bool = true) -> Annotation {
        Annotation(style: Self.style, shape: .rectangle(rect), extendsCanvas: extendsCanvas)
    }

    private func event(
        _ type: NSEvent.EventType, _ point: CGPoint, in view: NSView, flags: NSEvent.ModifierFlags = [],
        clickCount: Int = 1
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type, location: view.convert(point, to: nil), modifierFlags: flags, timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: clickCount,
            pressure: 1)!
    }

    private func click(
        _ controller: DocumentWindowController, _ point: CGPoint, flags: NSEvent.ModifierFlags = [],
        clickCount: Int = 1
    ) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, point, in: view, flags: flags, clickCount: clickCount))
        view.mouseUp(with: event(.leftMouseUp, point, in: view, flags: flags, clickCount: clickCount))
    }

    private func drag(
        _ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint, flags: NSEvent.ModifierFlags = []
    ) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: view, flags: flags))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: view, flags: flags))
        view.mouseUp(with: event(.leftMouseUp, b, in: view, flags: flags))
    }

    private func key(_ controller: DocumentWindowController, _ characters: String, keyCode: UInt16) throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode))
        controller.canvasView.keyDown(with: event)
    }

    @Test func clickSelectsAndEmptyClickClears() {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let b = rectangle(CGRect(x: 150, y: 20, width: 60, height: 40))
        let controller = makeController([a, b])
        defer { controller.close() }
        let selection = controller.selection

        click(controller, CGPoint(x: 50, y: 40))
        #expect(selection.selectedIDs.isEmpty)
        click(controller, CGPoint(x: 20, y: 40))
        #expect(selection.selectedIDs == [a.id])
        click(controller, CGPoint(x: 150, y: 40), flags: .shift)
        #expect(selection.selectedIDs == [a.id, b.id])
        click(controller, CGPoint(x: 20, y: 40), flags: .shift)
        #expect(selection.selectedIDs == [b.id])
        click(controller, CGPoint(x: 300, y: 200))
        #expect(selection.selectedIDs.isEmpty)
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func dragMovesSelectionInOneStep() {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let b = rectangle(CGRect(x: 150, y: 20, width: 60, height: 40))
        let controller = makeController([a, b])
        defer { controller.close() }
        let model = controller.model
        controller.selection.select([a.id, b.id])

        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 20, y: 40), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 25, y: 45), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 30, y: 50), in: view))
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 30, y: 50), in: view))

        #expect(model.document.annotations.map(\.shape) == [
            .rectangle(CGRect(x: 30, y: 30, width: 60, height: 40)),
            .rectangle(CGRect(x: 160, y: 30, width: 60, height: 40)),
        ])
        #expect(model.undoManager.undoActionName == "Move")
        model.undoManager.undo()
        #expect(model.document.annotations == [a, b])
        #expect(!model.undoManager.canUndo)
    }

    @Test func shiftConstrainsMoveToDominantAxis() {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let controller = makeController([a])
        defer { controller.close() }
        drag(controller, from: CGPoint(x: 20, y: 40), to: CGPoint(x: 50, y: 45), flags: .shift)
        #expect(controller.model.document.annotations[0].shape == .rectangle(CGRect(x: 50, y: 20, width: 60, height: 40)))
    }

    @Test func moveSetsExtendsCanvas() {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40), extendsCanvas: false)
        let controller = makeController([a])
        defer { controller.close() }
        click(controller, CGPoint(x: 20, y: 40))
        #expect(controller.model.document.annotations[0].extendsCanvas == false)
        drag(controller, from: CGPoint(x: 20, y: 40), to: CGPoint(x: 30, y: 40))
        #expect(controller.model.document.annotations[0].extendsCanvas)
    }

    @Test func cornerHandleResizes() {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let controller = makeController([a])
        defer { controller.close() }
        controller.selection.select([a.id])
        drag(controller, from: CGPoint(x: 80, y: 60), to: CGPoint(x: 120, y: 100))
        let model = controller.model
        #expect(model.document.annotations[0].shape == .rectangle(CGRect(x: 20, y: 20, width: 100, height: 80)))
        #expect(model.undoManager.undoActionName == "Resize")
    }

    @Test func endpointDragMovesOnlyThatEnd() {
        let start = CGPoint(x: 20, y: 20), end = CGPoint(x: 120, y: 80)
        let line = Annotation(style: Self.style, shape: .line(start: start, end: end))
        let controller = makeController([line])
        defer { controller.close() }
        controller.selection.select([line.id])
        drag(controller, from: end, to: CGPoint(x: 150, y: 30))
        let model = controller.model
        #expect(model.document.annotations[0].shape == .line(start: start, end: CGPoint(x: 150, y: 30)))
        #expect(model.undoManager.undoActionName == "Move Endpoint")

        drag(controller, from: CGPoint(x: 150, y: 30), to: CGPoint(x: 200, y: 25), flags: .shift)
        guard case .line(let s, let e) = model.document.annotations[0].shape else {
            Issue.record("not a line")
            return
        }
        #expect(s == start)
        #expect(e.y == start.y)
    }

    @Test func marqueeSelectsIntersecting() {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let b = rectangle(CGRect(x: 150, y: 20, width: 60, height: 40))
        let c = rectangle(CGRect(x: 20, y: 200, width: 60, height: 40))
        let controller = makeController([a, b, c])
        defer { controller.close() }
        let selection = controller.selection
        drag(controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 160, y: 100))
        #expect(selection.selectedIDs == [a.id, b.id])
        #expect(!controller.model.undoManager.canUndo)
        drag(controller, from: CGPoint(x: 10, y: 190), to: CGPoint(x: 30, y: 210), flags: .shift)
        #expect(selection.selectedIDs == [a.id, b.id, c.id])
    }

    @Test func marqueeTouchesDrawnGeometryOnly() {
        let arrow = Annotation(
            style: Self.style, shape: .arrow(tail: CGPoint(x: 200, y: 50), head: CGPoint(x: 300, y: 150)))
        let outline = rectangle(CGRect(x: 20, y: 20, width: 100, height: 100))
        let controller = makeController([arrow, outline])
        defer { controller.close() }
        let selection = controller.selection
        drag(controller, from: CGPoint(x: 280, y: 40), to: CGPoint(x: 310, y: 60))
        drag(controller, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 90, y: 90), flags: .shift)
        #expect(selection.isEmpty)
        drag(controller, from: CGPoint(x: 240, y: 80), to: CGPoint(x: 260, y: 100))
        #expect(selection.selectedIDs == [arrow.id])
    }

    @Test func deleteEscapeAndSelectAll() throws {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let b = rectangle(CGRect(x: 150, y: 20, width: 60, height: 40))
        let controller = makeController([a, b])
        defer { controller.close() }
        let model = controller.model
        let selection = controller.selection
        let selectAll = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "")
        let delete = NSMenuItem(title: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        #expect(!controller.validateMenuItem(delete))
        #expect(controller.validateMenuItem(selectAll))

        controller.selectAll(nil)
        #expect(selection.selectedIDs == [a.id, b.id])
        #expect(controller.validateMenuItem(delete))
        try key(controller, "\u{1B}", keyCode: 53)
        #expect(selection.isEmpty)

        selection.select([a.id])
        try key(controller, "\u{7F}", keyCode: 51)
        #expect(model.document.annotations == [b])
        #expect(model.undoManager.undoActionName == "Delete")
        #expect(selection.isEmpty)
        model.undoManager.undo()
        #expect(model.document.annotations == [a, b])

        selection.select([b.id])
        controller.delete(nil)
        #expect(model.document.annotations == [a])
    }

    @Test func escapeCancelsDragBeforeClearing() throws {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let controller = makeController([a])
        defer { controller.close() }
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, CGPoint(x: 20, y: 40), in: view))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 60, y: 40), in: view))
        try key(controller, "\u{1B}", keyCode: 53)
        #expect(controller.model.document.annotations == [a])
        #expect(controller.selection.selectedIDs == [a.id])
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 60, y: 40), in: view))
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func drawingToolClearsSelection() {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let controller = makeController([a])
        defer { controller.close() }
        controller.selection.select([a.id])
        controller.toolbar.activeTool = .select
        #expect(!controller.selection.isEmpty)
        controller.toolbar.activeTool = .arrow
        #expect(controller.selection.isEmpty)
    }

    @Test func paletteColorRecolorsSelection() {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let pixelate = Annotation(
            style: AnnotationStyle(color: Self.style.color, thickness: 10),
            shape: .pixelate(CGRect(x: 150, y: 20, width: 60, height: 40)))
        let controller = makeController([a, pixelate])
        defer { controller.close() }
        let model = controller.model
        let toolbar = controller.toolbar
        controller.selection.select([pixelate.id, a.id])
        #expect(toolbar.styleTool == .rectangle)
        #expect(toolbar.displayedStyle.color == Self.style.color)

        toolbar.selectColor(index: 4)
        #expect(model.document.annotations[0].style.color == Palette.colors[4])
        #expect(model.document.annotations[1].style.color == Self.style.color)
        #expect(toolbar.displayedStyle.color == Palette.colors[4])
        #expect(model.undoManager.undoActionName == "Change Color")
        #expect(settings.style(for: .rectangle).color == Palette.colors[4])
        #expect(settings.style(for: .pixelate) == ToolStyle.defaultStyle(for: .pixelate))
        #expect(settings.style(for: .select) == ToolStyle.defaultStyle(for: .select))
        model.undoManager.undo()
        #expect(model.document.annotations == [a, pixelate])
        #expect(!model.undoManager.canUndo)
    }

    @Test func thicknessEditsSelection() {
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40), extendsCanvas: false)
        let controller = makeController([a])
        defer { controller.close() }
        let model = controller.model
        let toolbar = controller.toolbar
        controller.selection.select([a.id])

        toolbar.perform(.thicknessStep(1))
        let stepped = model.document.annotations[0].style.thickness
        #expect(stepped > Self.style.thickness)
        #expect(model.document.annotations[0].extendsCanvas)
        #expect(model.undoManager.undoActionName == "Change Thickness")

        model.undoManager.removeAllActions()
        toolbar.beginThicknessDrag()
        for thickness: CGFloat in [8, 12, 16] { toolbar.setThickness(thickness) }
        toolbar.endThicknessDrag()
        #expect(model.document.annotations[0].style.thickness == 16)
        model.undoManager.undo()
        #expect(model.document.annotations[0].style.thickness == stepped)
        #expect(!model.undoManager.canUndo)
        #expect(settings.style(for: .rectangle).thickness == 16)
    }

    @Test func colorEditOfArrowSetsToolDefault() {
        let arrow = Annotation(style: Self.style, shape: .arrow(tail: CGPoint(x: 20, y: 20), head: CGPoint(x: 100, y: 80)))
        let controller = makeController([arrow])
        defer { controller.close() }
        controller.selection.select([arrow.id])
        controller.toolbar.selectColor(index: 3)
        #expect(settings.style(for: .arrow).color == Palette.colors[3])
        #expect(settings.style(for: .rectangle) == ToolStyle.defaultStyle(for: .rectangle))
    }

    @Test func thicknessEditOfMixedSelectionSetsEachToolDefault() {
        let arrow = Annotation(style: Self.style, shape: .arrow(tail: CGPoint(x: 20, y: 20), head: CGPoint(x: 100, y: 80)))
        let rect = rectangle(CGRect(x: 150, y: 20, width: 60, height: 40))
        let pixelate = Annotation(
            style: AnnotationStyle(color: Self.style.color, thickness: 10),
            shape: .pixelate(CGRect(x: 250, y: 20, width: 60, height: 40)))
        let controller = makeController([arrow, rect, pixelate])
        defer { controller.close() }
        controller.selection.select([arrow.id, rect.id])
        controller.toolbar.setThickness(12)
        #expect(settings.style(for: .arrow).thickness == 12)
        #expect(settings.style(for: .rectangle).thickness == 12)
        #expect(settings.style(for: .pixelate) == ToolStyle.defaultStyle(for: .pixelate))

        controller.selection.select([pixelate.id])
        controller.toolbar.stepThickness(by: 1)
        let size = controller.model.document.annotations[2].style.thickness
        #expect(size > 10)
        #expect(settings.style(for: .pixelate).thickness == size)
        #expect(settings.style(for: .arrow).thickness == 12)
    }

    @Test func fineStepOfMixedSelectionSetsEachToolDefault() {
        let arrow = Annotation(style: Self.style, shape: .arrow(tail: CGPoint(x: 20, y: 20), head: CGPoint(x: 100, y: 80)))
        let text = Annotation(
            style: AnnotationStyle(color: Self.style.color, thickness: 24),
            shape: .text(TextContent(origin: CGPoint(x: 150, y: 20), string: "Hi")))
        let controller = makeController([arrow, text])
        defer { controller.close() }
        controller.selection.select([arrow.id, text.id])
        controller.toolbar.perform(.thicknessFineStep(1))
        let annotations = controller.model.document.annotations
        #expect(annotations[0].style.thickness == Self.style.thickness + 0.5)
        #expect(annotations[1].style.thickness == 24.5)
        #expect(settings.style(for: .arrow).thickness == Self.style.thickness + 0.5)
        #expect(settings.style(for: .text).thickness == 24.5)
        controller.toolbar.perform(.thicknessFineStep(1))
        controller.model.undoManager.undo()
        #expect(controller.model.document.annotations[0].style.thickness == Self.style.thickness + 0.5)
    }

    private func arrowAndText() -> (arrow: Annotation, text: Annotation) {
        let arrow = Annotation(style: Self.style, shape: .arrow(tail: CGPoint(x: 20, y: 20), head: CGPoint(x: 100, y: 80)))
        let text = Annotation(
            style: AnnotationStyle(color: Self.style.color, thickness: 24),
            shape: .text(TextContent(origin: CGPoint(x: 150, y: 20), string: "Hi")))
        return (arrow, text)
    }

    @Test func sliderPositionAppliesPerObjectRange() throws {
        let (arrow, text) = arrowAndText()
        let controller = makeController([arrow, text])
        defer { controller.close() }
        controller.selection.select([arrow.id, text.id])
        let toolbar = controller.toolbar
        let annotations = { controller.model.document.annotations }

        toolbar.setThickness(atPosition: 1)
        #expect(annotations()[0].style.thickness == 40)
        #expect(annotations()[1].style.thickness == 120)
        #expect(settings.style(for: .arrow).thickness == 40)
        #expect(settings.style(for: .text).thickness == 120)

        toolbar.setThickness(atPosition: 0.5)
        let arrowRange = try #require(Tool.arrow.thicknessRange)
        let textRange = try #require(Tool.text.thicknessRange)
        #expect(annotations()[0].style.thickness == ThicknessScale.value(at: 0.5, in: arrowRange))
        #expect(annotations()[1].style.thickness == ThicknessScale.value(at: 0.5, in: textRange))
        #expect(settings.style(for: .text).thickness == annotations()[1].style.thickness)

        let shown = toolbar.displayedStyle.thickness
        #expect(ThicknessScale.value(at: ThicknessScale.position(of: shown, in: textRange), in: textRange) == shown)
    }

    @Test func toolbarShowsLastSelectedObject() {
        let (arrow, text) = arrowAndText()
        let rect = rectangle(CGRect(x: 250, y: 20, width: 60, height: 40))
        let controller = makeController([arrow, text, rect])
        defer { controller.close() }
        let toolbar = controller.toolbar
        controller.selection.select([arrow.id])
        #expect(toolbar.styleTool == .arrow)
        controller.selection.select([arrow.id, text.id])
        #expect(toolbar.styleTool == .text)
        #expect(toolbar.displayedStyle.thickness == 24)
        controller.selection.toggle(rect.id)
        #expect(toolbar.styleTool == .rectangle)
        #expect(toolbar.displayedStyle.thickness == 4)
    }

    @Test func sliderDragUpdatesDefaultsContinuously() {
        let rect = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let controller = makeController([rect])
        defer { controller.close() }
        controller.selection.select([rect.id])
        controller.toolbar.beginThicknessDrag()
        controller.toolbar.setThickness(9)
        #expect(settings.style(for: .rectangle).thickness == 9)
        controller.toolbar.endThicknessDrag()
        #expect(settings.style(for: .rectangle).thickness == 9)
    }

    @Test func movingSelectionLeavesDefaultsUnchanged() {
        let rect = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        let controller = makeController([rect])
        defer { controller.close() }
        controller.selection.select([rect.id])
        drag(controller, from: CGPoint(x: 20, y: 40), to: CGPoint(x: 60, y: 80))
        #expect(controller.model.document.annotations[0] != rect)
        #expect(settings.styles == ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore())).styles)
    }

    @Test func sliderCellReportsTracking() {
        let slider = NSSlider(frame: NSRect(x: 0, y: 0, width: 22, height: 100))
        let cell = WedgeSliderCell()
        slider.cell = cell
        var events: [String] = []
        cell.onTrackingBegin = { events.append("begin") }
        cell.onTrackingEnd = { events.append("end") }
        _ = cell.startTracking(at: NSPoint(x: 11, y: 50), in: slider)
        cell.stopTracking(last: NSPoint(x: 11, y: 50), current: NSPoint(x: 11, y: 60), in: slider, mouseIsUp: true)
        #expect(events == ["begin", "end"])
    }

    @Test func doubleClickOnTextStartsEditing() throws {
        let text = Annotation(
            style: AnnotationStyle(color: Self.style.color, thickness: 40),
            shape: .text(TextContent(origin: CGPoint(x: 20, y: 20), string: "I")))
        let controller = makeController([text])
        defer { controller.close() }
        let glyphs = try #require(TextLayout.path(of: TextContent(origin: CGPoint(x: 20, y: 20), string: "I"), fontSize: 40))
        let point = CGPoint(x: glyphs.boundingBoxOfPath.midX, y: glyphs.boundingBoxOfPath.midY)
        click(controller, point)
        #expect(!controller.canvasView.textEditor.isEditing)
        click(controller, point, clickCount: 2)
        #expect(controller.canvasView.textEditor.isEditing)
        #expect(controller.selection.selectedIDs == [text.id])
        controller.canvasView.commitTextEditing()
        #expect(!controller.model.isInGesture)
    }

    @Test func doubleClickBetweenLettersStartsEditing() {
        let text = Annotation(
            style: AnnotationStyle(color: Self.style.color, thickness: 40),
            shape: .text(TextContent(origin: CGPoint(x: 20, y: 20), string: "I I")))
        let controller = makeController([text])
        defer { controller.close() }
        let point = CGPoint(x: text.bounds.midX, y: text.bounds.midY)
        click(controller, point, clickCount: 2)
        #expect(controller.canvasView.textEditor.isEditing)
        #expect(controller.selection.selectedIDs == [text.id])
        controller.canvasView.commitTextEditing()
    }

    @Test func undoOfCreationDropsSelection() {
        let controller = makeController([])
        defer { controller.close() }
        let model = controller.model
        let a = rectangle(CGRect(x: 20, y: 20, width: 60, height: 40))
        model.perform("Draw Rectangle") { $0.annotations.append(a) }
        controller.selection.select([a.id])
        model.undoManager.undo()
        #expect(controller.selection.isEmpty)
        #expect(controller.toolbar.styleTool == .select)
    }
}
