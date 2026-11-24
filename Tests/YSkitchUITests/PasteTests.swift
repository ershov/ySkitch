import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct PasteTests {
    private func makeController() -> DocumentWindowController {
        DocumentWindowController(
            document: Document(blankSize: CGSize(width: 50, height: 30), scale: 1),
            title: "Test",
            toolSettings: ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore())))
    }

    private func privatePasteboard() -> NSPasteboard {
        NSPasteboard(name: .init("ySkitch.tests.\(UUID().uuidString)"))
    }

    private func pngData(pixels: Int) throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        bitmap.size = CGSize(width: CGFloat(pixels) / 2, height: CGFloat(pixels) / 2)
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    @Test func pasteReplacesDocumentAsOneUndoStep() throws {
        let controller = makeController()
        defer { controller.close() }
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }
        controller.model.perform("Draw Rectangle") {
            $0.annotations.append(Annotation(
                style: AnnotationStyle(color: RGBAColor(red: 1, green: 0, blue: 0, alpha: 1), thickness: 2),
                shape: .rectangle(CGRect(x: 1, y: 1, width: 10, height: 10))))
        }
        let original = controller.model.document
        let drawUndoCount = controller.model.undoManager.canUndo
        #expect(drawUndoCount)
        pasteboard.setData(try pngData(pixels: 40), forType: .png)

        #expect(controller.paste(from: pasteboard))

        let pasted = controller.model.document
        #expect(pasted.scale == CGFloat(2))
        #expect(pasted.base?.cgImage.width == 40)
        #expect(pasted.base?.cgImage.height == 40)
        #expect(pasted.annotations.isEmpty)
        #expect(controller.model.undoManager.undoActionName == "Paste Image")

        controller.model.undoManager.undo()
        #expect(controller.model.document == original)
        #expect(controller.model.undoManager.undoActionName == "Draw Rectangle")

        controller.model.undoManager.redo()
        #expect(controller.model.document == pasted)
    }

    @Test func emptyPasteboardChangesNothing() {
        let controller = makeController()
        defer { controller.close() }
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }
        let original = controller.model.document

        #expect(!controller.paste(from: pasteboard))

        #expect(controller.model.document == original)
        #expect(!controller.model.undoManager.canUndo)
    }

    @Test func pasteResetsSavedURLAndResizesCanvas() throws {
        let controller = makeController()
        defer { controller.close() }
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setData(try pngData(pixels: 40), forType: .png)

        controller.paste(from: pasteboard)

        #expect(controller.savedURL == nil)
        #expect(controller.canvasView.frame.size == controller.model.document.canvasRect.size)
        #expect(controller.window?.title == controller.defaultFileName)
    }

    @Test func undoPasteImageRestoresTitleAndSavedURL() throws {
        let saved = URL(fileURLWithPath: "/tmp/ySkitch-test.png")
        let controller = DocumentWindowController(
            model: DocumentModel(document: Document(blankSize: CGSize(width: 50, height: 30), scale: 1)),
            title: "Test", savedURL: saved,
            toolSettings: ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore())))
        defer { controller.close() }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("Other.png")
        try pngData(pixels: 40).write(to: file)
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.writeObjects([file as NSURL])

        #expect(controller.paste(from: pasteboard))
        let pastedName = controller.defaultFileName
        #expect(pastedName.contains("Other"))
        #expect(controller.savedURL == nil)
        #expect(controller.model.undoManager.undoMenuItemTitle == "Undo Paste Image")

        controller.model.undoManager.undo()
        #expect(controller.window?.title == "Test")
        #expect(controller.defaultFileName == "Test")
        #expect(controller.savedURL == saved)
        #expect(controller.model.undoManager.redoMenuItemTitle == "Redo Paste Image")

        controller.model.undoManager.redo()
        #expect(controller.window?.title == pastedName)
        #expect(controller.savedURL == nil)
    }
}
