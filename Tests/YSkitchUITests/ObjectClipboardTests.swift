import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct ObjectClipboardTests {
    private static let style = AnnotationStyle(color: RGBAColor(hex: 0xFF2500), thickness: 4)

    private func makeController() -> DocumentWindowController {
        DocumentWindowController(
            document: Document(blankSize: CGSize(width: 100, height: 100), scale: 1),
            title: "Test",
            toolSettings: ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore())))
    }

    private func privatePasteboard() -> NSPasteboard {
        NSPasteboard(name: .init("ySkitch.tests.\(UUID().uuidString)"))
    }

    private func rectangle(_ x: CGFloat) -> Annotation {
        Annotation(style: Self.style, shape: .rectangle(CGRect(x: x, y: 5, width: 20, height: 10)))
    }

    private func controllerWithSelection() -> (DocumentWindowController, [Annotation]) {
        let controller = makeController()
        let items = [rectangle(10), rectangle(40)]
        controller.model.perform("Draw") { $0.annotations = items }
        controller.selection.select(items.map(\.id))
        return (controller, items)
    }

    private func rects(_ annotations: [Annotation]) -> [CGRect] {
        annotations.compactMap { if case .rectangle(let rect) = $0.shape { rect } else { nil } }
    }

    @Test func copyWithSelectionWritesOnlyPrivateType() {
        let (controller, _) = controllerWithSelection()
        defer { controller.close() }
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }

        controller.copy(to: pasteboard)

        #expect(pasteboard.data(forType: .annotations) != nil)
        #expect(pasteboard.data(forType: .png) == nil)
        #expect(pasteboard.data(forType: .tiff) == nil)
    }

    @Test func copyWithoutSelectionWritesImage() {
        let controller = makeController()
        defer { controller.close() }
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }

        controller.copy(to: pasteboard)

        #expect(pasteboard.data(forType: .annotations) == nil)
        #expect(pasteboard.data(forType: .png) != nil)
        #expect(pasteboard.data(forType: .tiff) != nil)
    }

    @Test func pasteIntoOtherWindow() {
        let (source, items) = controllerWithSelection()
        let target = makeController()
        defer { source.close(); target.close() }
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }
        source.copy(to: pasteboard)

        #expect(target.paste(from: pasteboard))

        let pasted = target.model.document.annotations
        #expect(rects(pasted) == rects(items))
        #expect(Set(pasted.map(\.id)).isDisjoint(with: items.map(\.id)))
        #expect(target.selection.selectedIDs == pasted.map(\.id))
        #expect(target.toolbar.activeTool == .select)
        #expect(target.model.undoManager.undoActionName == "Paste")
        target.model.undoManager.undo()
        #expect(target.model.document.annotations.isEmpty)
        #expect(!target.model.undoManager.canUndo)
    }

    @Test func pasteIntoSameWindowCascades() {
        let (controller, items) = controllerWithSelection()
        defer { controller.close() }
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }
        controller.copy(to: pasteboard)

        controller.paste(from: pasteboard)
        controller.paste(from: pasteboard)

        let all = controller.model.document.annotations
        #expect(all.count == 6)
        #expect(rects(Array(all[2..<4])) == rects(items).map { $0.offsetBy(dx: 10, dy: 10) })
        #expect(rects(Array(all[4..<6])) == rects(items).map { $0.offsetBy(dx: 20, dy: 20) })
    }

    @Test func annotationsTakePrecedenceOverImage() throws {
        let (source, _) = controllerWithSelection()
        let target = makeController()
        defer { source.close(); target.close() }
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }
        source.copy(to: pasteboard)
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        pasteboard.setData(bitmap.representation(using: .png, properties: [:]), forType: .png)
        let base = target.model.document.base

        #expect(target.paste(from: pasteboard))

        #expect(target.model.document.annotations.count == 2)
        #expect(target.model.document.base == base)
    }

    @Test func cutRemovesSelectionAndCopies() {
        let (controller, _) = controllerWithSelection()
        defer { controller.close() }
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }

        controller.cut(to: pasteboard)

        #expect(controller.model.document.annotations.isEmpty)
        #expect(pasteboard.data(forType: .annotations) != nil)
        #expect(controller.model.undoManager.undoActionName == "Cut")
        controller.model.undoManager.undo()
        #expect(controller.model.document.annotations.count == 2)
        #expect(controller.model.undoManager.undoActionName == "Draw")
    }

    @Test func duplicateOffsetsAndSelects() {
        let (controller, items) = controllerWithSelection()
        defer { controller.close() }

        controller.duplicate(nil)

        let all = controller.model.document.annotations
        #expect(all.count == 4)
        #expect(rects(Array(all[2...])) == rects(items).map { $0.offsetBy(dx: 10, dy: 10) })
        #expect(controller.selection.selectedIDs == all[2...].map(\.id))
        #expect(controller.model.undoManager.undoActionName == "Duplicate")
        controller.model.undoManager.undo()
        #expect(controller.model.document.annotations == items)
    }

    @Test func menuValidation() {
        let controller = makeController()
        defer { controller.close() }
        let cut = NSMenuItem(title: "Cut", action: #selector(DocumentWindowController.cut(_:)), keyEquivalent: "")
        let duplicate = NSMenuItem(
            title: "Duplicate", action: #selector(DocumentWindowController.duplicate(_:)), keyEquivalent: "")
        let copy = NSMenuItem(title: "Copy", action: #selector(DocumentWindowController.copy(_:)), keyEquivalent: "")
        #expect(!controller.validateMenuItem(cut))
        #expect(!controller.validateMenuItem(duplicate))
        #expect(controller.validateMenuItem(copy))

        let item = rectangle(1)
        controller.model.perform("Draw") { $0.annotations = [item] }
        controller.selection.select([item.id])
        #expect(controller.validateMenuItem(cut))
        #expect(controller.validateMenuItem(duplicate))
    }
}
