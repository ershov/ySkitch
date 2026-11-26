import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct CropToolTests {
    private let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
    private static let imageRect = CGRect(x: 0, y: 0, width: 400, height: 300)

    private func makeController(scale: CGFloat = 1, annotations: [Annotation] = []) -> DocumentWindowController {
        var document = Document(blankSize: Self.imageRect.size, scale: scale)
        document.annotations = annotations
        let controller = DocumentWindowController(document: document, title: "Test", toolSettings: settings)
        controller.toolbar.activeTool = .arrow
        return controller
    }

    /// `point` is in document coordinates.
    private func event(
        _ type: NSEvent.EventType, _ point: CGPoint, in controller: DocumentWindowController, clickCount: Int = 1,
        flags: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        let view = controller.canvasView
        let origin = controller.model.document.canvasRect.origin
        let local = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        return NSEvent.mouseEvent(
            with: type, location: view.convert(local, to: nil), modifierFlags: flags, timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: clickCount,
            pressure: 1)!
    }

    private func doubleClick(_ controller: DocumentWindowController, at point: CGPoint) {
        let view = controller.canvasView
        for clickCount in 1...2 {
            view.mouseDown(with: event(.leftMouseDown, point, in: controller, clickCount: clickCount))
            view.mouseUp(with: event(.leftMouseUp, point, in: controller, clickCount: clickCount))
        }
    }

    private func drag(
        _ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint, flags: NSEvent.ModifierFlags = []
    ) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: controller, flags: flags))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: controller, flags: flags))
        view.mouseUp(with: event(.leftMouseUp, b, in: controller, flags: flags))
    }

    private func key(_ controller: DocumentWindowController, _ characters: String, keyCode: UInt16) throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode))
        controller.canvasView.keyDown(with: event)
    }

    private func pressReturn(_ controller: DocumentWindowController) throws {
        try key(controller, "\r", keyCode: 36)
    }

    private func crop(_ controller: DocumentWindowController, to rect: CGRect) {
        controller.model.perform("Crop") { $0.applyCrop(rect) }
    }

    @Test func activatingShowsFullImage() {
        let controller = makeController()
        defer { controller.close() }
        let cropped = CGRect(x: 50, y: 40, width: 100, height: 80)
        crop(controller, to: cropped)
        #expect(controller.model.document.canvasRect == cropped)

        controller.toolbar.activeTool = .crop
        let document = controller.model.document
        #expect(document.cropRect == nil)
        #expect(document.canvasRect == Self.imageRect)
        #expect(controller.model.isInGesture)
        #expect(controller.canvasView.isCropping)
        #expect(controller.canvasView.proposedCropRect == cropped)
    }

    @Test func dragNewRectAndReturnApplies() throws {
        let controller = makeController(scale: 2)
        defer { controller.close() }
        let model = controller.model
        let original = model.document

        controller.toolbar.activeTool = .crop
        #expect(controller.canvasView.proposedCropRect == Self.imageRect)
        drag(controller, from: CGPoint(x: 10.3, y: 20.2), to: CGPoint(x: 110.6, y: 80.1))
        try pressReturn(controller)

        #expect(model.document.cropRect == CGRect(x: 10, y: 20, width: 101, height: 60.5))
        #expect(model.document.canvasRect == model.document.cropRect)
        #expect(!model.isInGesture)
        #expect(!controller.canvasView.isCropping)
        #expect(controller.toolbar.activeTool == .arrow)
        #expect(model.undoManager.undoActionName == "Crop")

        model.undoManager.undo()
        #expect(model.document == original)
        #expect(!model.undoManager.canUndo)
    }

    @Test func optionDrawsNewRectFromCenter() {
        let controller = makeController()
        defer { controller.close() }
        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 130, y: 80), flags: .option)
        #expect(controller.canvasView.proposedCropRect == CGRect(x: 70, y: 80, width: 60, height: 40))
    }

    @Test func optionResizesAroundCenterAndShiftKeepsRatio() {
        let controller = makeController()
        defer { controller.close() }
        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 200, y: 150))
        let view = controller.canvasView
        let handle = CGPoint(x: 200, y: 150)
        view.mouseDown(with: event(.leftMouseDown, handle, in: controller))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 220, y: 150), in: controller, flags: .option))
        #expect(view.proposedCropRect == CGRect(x: 80, y: 100, width: 140, height: 50))
        view.mouseDragged(with: event(.leftMouseDragged, CGPoint(x: 300, y: 200), in: controller, flags: .shift))
        #expect(view.proposedCropRect == CGRect(x: 100, y: 100, width: 200, height: 100))
        view.mouseUp(with: event(.leftMouseUp, CGPoint(x: 300, y: 200), in: controller))
    }

    @Test func applyResetsCanvasExtension() throws {
        let outside = Annotation(
            style: AnnotationStyle(color: RGBAColor(hex: 0xFF0000), thickness: 4),
            shape: .rectangle(CGRect(x: 350, y: 250, width: 100, height: 100)))
        let controller = makeController(annotations: [outside])
        defer { controller.close() }
        let model = controller.model
        model.perform("Fit") { _ in }
        #expect(model.document.canvasRect.maxX > Self.imageRect.maxX)

        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 120))
        try pressReturn(controller)
        #expect(model.document.canvasRect == CGRect(x: 20, y: 20, width: 100, height: 100))
        #expect(model.document.annotations.allSatisfy { !$0.extendsCanvas })
    }

    @Test func escapeCancels() throws {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        crop(controller, to: CGRect(x: 50, y: 40, width: 100, height: 80))
        let cropped = model.document

        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 200, y: 200))
        try key(controller, "\u{1b}", keyCode: 53)

        #expect(model.document == cropped)
        #expect(!model.isInGesture)
        #expect(model.undoManager.undoActionName == "Crop")
        model.undoManager.undo()
        #expect(!model.undoManager.canUndo)
        #expect(controller.toolbar.activeTool == .arrow)
    }

    @Test func switchingToolCancels() {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        let original = model.document

        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 200, y: 200))
        controller.toolbar.activeTool = .rectangle

        #expect(model.document == original)
        #expect(!model.isInGesture)
        #expect(!model.undoManager.canUndo)
        #expect(controller.canvasView.proposedCropRect == nil)
    }

    @Test func recropBeyondImageGrowsCanvasAndPads() throws {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        let view = controller.canvasView
        crop(controller, to: CGRect(x: 50, y: 40, width: 100, height: 80))

        controller.toolbar.activeTool = .crop
        #expect(model.document.canvasRect == Self.imageRect)
        drag(controller, from: CGPoint(x: 50, y: 40), to: CGPoint(x: -100, y: -50))
        #expect(view.proposedCropRect == CGRect(x: -100, y: -50, width: 250, height: 170))
        #expect(model.document.canvasRect == CGRect(x: -100, y: -50, width: 500, height: 350))
        #expect(view.frame.size == model.document.canvasRect.size)
        drag(controller, from: CGPoint(x: 150, y: 120), to: CGPoint(x: 450, y: 320))
        let padded = CGRect(x: -100, y: -50, width: 550, height: 370)
        #expect(view.proposedCropRect == padded)
        #expect(model.document.canvasRect == padded)
        #expect(view.frame.size == padded.size)
        try pressReturn(controller)

        #expect(model.document.cropRect == padded)
        #expect(model.document.canvasRect == padded)
        #expect(view.frame.size == padded.size)
        #expect(model.undoManager.undoActionName == "Crop")
    }

    @Test func escapeRestoresCanvasGrownBySession() throws {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 400, y: 300), to: CGPoint(x: 500, y: 350))
        #expect(model.document.canvasRect == CGRect(x: 0, y: 0, width: 500, height: 350))
        try key(controller, "\u{1b}", keyCode: 53)
        #expect(model.document.canvasRect == Self.imageRect)
        #expect(controller.canvasView.frame.size == Self.imageRect.size)
        #expect(!model.undoManager.canUndo)
    }

    @Test func dragInsideMovesBeyondCanvas() {
        let controller = makeController()
        defer { controller.close() }
        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60))
        drag(controller, from: CGPoint(x: 50, y: 30), to: CGPoint(x: 1000, y: 30))
        #expect(controller.canvasView.proposedCropRect == CGRect(x: 960, y: 10, width: 100, height: 50))
        #expect(controller.model.document.canvasRect == CGRect(x: 0, y: 0, width: 1060, height: 300))
    }

    @Test func doubleClickProposesCurrentImage() {
        let controller = makeController()
        defer { controller.close() }
        let padded = CGRect(x: -20, y: -10, width: 440, height: 320)
        crop(controller, to: padded)

        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60))
        #expect(controller.canvasView.proposedCropRect == CGRect(x: 10, y: 10, width: 100, height: 50))
        doubleClick(controller, at: CGPoint(x: 200, y: 200))
        #expect(controller.canvasView.proposedCropRect == padded)
        #expect(controller.canvasView.proposedCropRect == controller.model.document.canvasRect)
    }

    @Test func doubleClickThenHandleDragPads() throws {
        let controller = makeController()
        defer { controller.close() }
        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60))
        doubleClick(controller, at: CGPoint(x: 50, y: 30))
        #expect(controller.canvasView.proposedCropRect == Self.imageRect)
        drag(controller, from: CGPoint(x: 0, y: 0), to: CGPoint(x: -30, y: -20))
        try pressReturn(controller)
        #expect(controller.model.document.canvasRect == CGRect(x: -30, y: -20, width: 430, height: 320))
    }

    @Test func paddingSurvivesEditsAndUndoRedo() throws {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 0, y: 0), to: CGPoint(x: -30, y: -20))
        drag(controller, from: CGPoint(x: 400, y: 300), to: CGPoint(x: 430, y: 320))
        try pressReturn(controller)
        let padded = CGRect(x: -30, y: -20, width: 460, height: 340)
        #expect(model.document.canvasRect == padded)

        controller.toolbar.activeTool = .rectangle
        drag(controller, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 200, y: 200))
        #expect(model.document.annotations.count == 1)
        #expect(model.document.canvasRect == padded)
        let id = try #require(model.document.annotations.first?.id)
        controller.selection.select([id])
        controller.selection.deleteSelected()
        #expect(model.document.annotations.isEmpty)
        #expect(model.document.canvasRect == padded)

        model.undoManager.undo()
        #expect(model.document.annotations.count == 1)
        #expect(model.document.canvasRect == padded)
        model.undoManager.undo()
        #expect(model.document.annotations.isEmpty)
        #expect(model.document.canvasRect == padded)
        model.undoManager.undo()
        #expect(model.document.canvasRect == Self.imageRect)
        model.undoManager.redo()
        #expect(model.document.canvasRect == padded)
        #expect(controller.canvasView.frame.size == padded.size)
        model.undoManager.redo()
        model.undoManager.redo()
        #expect(model.document.annotations.isEmpty)
        #expect(model.document.canvasRect == padded)
    }

    @Test func statusShowsCoordinatesBeyondImage() {
        let controller = makeController()
        defer { controller.close() }
        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 0, y: 0), to: CGPoint(x: -20, y: -10))
        drag(controller, from: CGPoint(x: 400, y: 300), to: CGPoint(x: 420, y: 300))
        #expect(controller.statusBar.infoLabel.stringValue == "Crop · (-20, -10) → (420, 300) · 440×310 px")
    }

    @Test func statusIsRelativeToCurrentImageAfterCrop() {
        let controller = makeController()
        defer { controller.close() }
        crop(controller, to: CGRect(x: 50, y: 40, width: 100, height: 80))
        controller.toolbar.activeTool = .crop
        #expect(controller.statusBar.infoLabel.stringValue == "Crop · (0, 0) → (100, 80) · 100×80 px")
        drag(controller, from: CGPoint(x: 50, y: 40), to: CGPoint(x: 30, y: 20))
        #expect(controller.statusBar.infoLabel.stringValue == "Crop · (-20, -20) → (100, 80) · 120×100 px")
    }

    @Test func clickOutsideKeepsRect() {
        let controller = makeController()
        defer { controller.close() }
        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60))
        drag(controller, from: CGPoint(x: 200, y: 200), to: CGPoint(x: 200, y: 200))
        #expect(controller.canvasView.proposedCropRect == CGRect(x: 10, y: 10, width: 100, height: 50))
    }

    @Test func undoAndDocumentActionsDisabledWhileCropping() {
        let controller = makeController()
        defer { controller.close() }
        crop(controller, to: CGRect(x: 50, y: 40, width: 100, height: 80))
        let undo = NSMenuItem(title: "Undo", action: #selector(UndoActions.undo(_:)), keyEquivalent: "")
        let save = NSMenuItem(title: "Save", action: #selector(DocumentWindowController.saveDocument(_:)), keyEquivalent: "")
        #expect(controller.canvasView.validateMenuItem(undo))
        #expect(controller.validateMenuItem(save))

        controller.toolbar.activeTool = .crop
        #expect(!controller.canvasView.validateMenuItem(undo))
        #expect(!controller.validateMenuItem(save))
        controller.canvasView.undo(nil)
        #expect(controller.model.isInGesture)
    }

    @Test func cropIsNotRememberedAsLastTool() {
        let controller = makeController()
        defer { controller.close() }
        controller.toolbar.activeTool = .crop
        #expect(settings.preferences.lastTool == .arrow)
    }

    @Test func dragHandleDisabledWhileCropping() throws {
        let controller = makeController(scale: 2)
        defer { controller.close() }
        let handle = controller.statusBar.dragHandle
        #expect(handle.isEnabled)
        #expect(handle.imageProvider?() != nil)

        controller.toolbar.activeTool = .crop
        #expect(!handle.isEnabled)
        #expect(handle.imageProvider?() == nil)
        drag(controller, from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 80))
        try pressReturn(controller)

        #expect(handle.isEnabled)
        let payload = try #require(handle.imageProvider?())
        let image = try ImageImporter.load(data: payload.png)
        #expect(image.cgImage.width == 200)
        #expect(image.cgImage.height == 120)

        controller.toolbar.activeTool = .crop
        #expect(!handle.isEnabled)
        try key(controller, "\u{1b}", keyCode: 53)
        #expect(handle.isEnabled)
    }
}
