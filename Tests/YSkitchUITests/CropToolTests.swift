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
    private func event(_ type: NSEvent.EventType, _ point: CGPoint, in controller: DocumentWindowController) -> NSEvent {
        let view = controller.canvasView
        let origin = controller.model.document.canvasRect.origin
        let local = CGPoint(x: point.x - origin.x, y: point.y - origin.y)
        return NSEvent.mouseEvent(
            with: type, location: view.convert(local, to: nil), modifierFlags: [], timestamp: 0,
            windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    private func drag(_ controller: DocumentWindowController, from a: CGPoint, to b: CGPoint) {
        let view = controller.canvasView
        view.mouseDown(with: event(.leftMouseDown, a, in: controller))
        view.mouseDragged(with: event(.leftMouseDragged, b, in: controller))
        view.mouseUp(with: event(.leftMouseUp, b, in: controller))
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

    @Test func recropEnlargesToWholeImage() throws {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        crop(controller, to: CGRect(x: 50, y: 40, width: 100, height: 80))

        controller.toolbar.activeTool = .crop
        #expect(model.document.canvasRect == Self.imageRect)
        drag(controller, from: CGPoint(x: 50, y: 40), to: CGPoint(x: -100, y: -100))
        #expect(controller.canvasView.proposedCropRect == CGRect(x: 0, y: 0, width: 150, height: 120))
        drag(controller, from: CGPoint(x: 150, y: 120), to: CGPoint(x: 900, y: 900))
        #expect(controller.canvasView.proposedCropRect == Self.imageRect)
        try pressReturn(controller)

        #expect(model.document.cropRect == Self.imageRect)
        #expect(model.document.canvasRect == Self.imageRect)
        #expect(model.undoManager.undoActionName == "Crop")
    }

    @Test func dragInsideMovesWithinCanvas() {
        let controller = makeController()
        defer { controller.close() }
        controller.toolbar.activeTool = .crop
        drag(controller, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60))
        drag(controller, from: CGPoint(x: 50, y: 30), to: CGPoint(x: 1000, y: 30))
        #expect(controller.canvasView.proposedCropRect == CGRect(x: 300, y: 10, width: 100, height: 50))
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
}
