import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct OutputScaleTests {
    private func makeController(_ document: Document = Document(blankSize: CGSize(width: 1440, height: 900), scale: 2))
        -> DocumentWindowController
    {
        DocumentWindowController(document: document, title: "Test", toolSettings: .inMemory())
    }

    private func imageMenuItem(_ title: String) throws -> NSMenuItem {
        let menu = try #require(MainMenu.build().items.first { $0.submenu?.title == "Image" }?.submenu)
        return try #require(menu.items.first { $0.title == title })
    }

    private func select(_ title: String, in controller: DocumentWindowController) {
        let button = controller.statusBar.scaleButton
        button.selectItem(withTitle: title)
        button.sendAction(button.action, to: button.target)
    }

    @Test func popUpListsChoicesWithCurrentSelected() {
        let controller = makeController()
        defer { controller.close() }
        let button = controller.statusBar.scaleButton
        #expect(button.itemTitles == ["@1x", "@2x", "@3x"])
        #expect(button.titleOfSelectedItem == "@2x")
        #expect(button.selectedItem?.state == .on)
        #expect(button.isEnabled)
    }

    @Test func popUpAddsUnlistedCurrentScale() {
        let controller = makeController(Document(blankSize: CGSize(width: 10, height: 10), scale: 4))
        defer { controller.close() }
        #expect(controller.statusBar.scaleButton.itemTitles == ["@1x", "@2x", "@3x", "@4x"])
        #expect(controller.statusBar.scaleButton.titleOfSelectedItem == "@4x")
    }

    @Test func popUpChangesScaleInOneUndoStep() {
        let controller = makeController()
        defer { controller.close() }
        let model = controller.model
        let original = model.document

        select("@1x", in: controller)
        #expect(model.document.scale == 1)
        #expect(controller.statusBar.infoLabel.stringValue == "1440×900 px · 1440×900 pt")
        #expect(controller.statusBar.scaleButton.titleOfSelectedItem == "@1x")
        #expect(model.undoManager.undoActionName == "Change Scale")

        model.undoManager.undo()
        #expect(model.document == original)
        #expect(!model.undoManager.canUndo)
        #expect(controller.statusBar.infoLabel.stringValue == "2880×1800 px · 1440×900 pt")
        #expect(controller.statusBar.scaleButton.titleOfSelectedItem == "@2x")
    }

    @Test func popUpStaysVisibleWithElementInfo() {
        var document = Document(blankSize: CGSize(width: 400, height: 300), scale: 2)
        let annotation = Annotation(
            style: AnnotationStyle(color: RGBAColor(hex: 0xFF0000), thickness: 4),
            shape: .rectangle(CGRect(x: 10, y: 10, width: 50, height: 40)))
        document.annotations = [annotation]
        let controller = makeController(document)
        defer { controller.close() }
        controller.selection.select([annotation.id])
        #expect(controller.statusBar.infoLabel.stringValue.hasPrefix("Rectangle"))
        #expect(!controller.statusBar.scaleButton.isHidden)
        #expect(controller.statusBar.scaleButton.titleOfSelectedItem == "@2x")
    }

    @Test func menuItemsChangeScaleAndCheckCurrent() throws {
        let controller = makeController()
        defer { controller.close() }
        for scale in [1, 2, 3] {
            let item = try imageMenuItem("Scale @\(scale)x")
            #expect(item.keyEquivalent == "\(scale)")
            #expect(item.keyEquivalentModifierMask == [.command, .option])
            #expect(item.action == #selector(DocumentWindowController.changeScale(_:)))
            #expect(item.target == nil)
        }
        let item3 = try imageMenuItem("Scale @3x")
        controller.changeScale(item3)
        #expect(controller.model.document.scale == 3)
        for scale in [1, 2, 3] {
            let item = try imageMenuItem("Scale @\(scale)x")
            #expect(controller.validateMenuItem(item))
            #expect(item.state == (scale == 3 ? .on : .off), "@\(scale)x")
        }
    }

    @Test func disabledWhileCropping() throws {
        let controller = makeController()
        defer { controller.close() }
        controller.toolbar.activeTool = .crop
        #expect(controller.canvasView.isCropping)
        let item = try imageMenuItem("Scale @1x")
        #expect(!controller.validateMenuItem(item))
        #expect(!controller.statusBar.scaleButton.isEnabled)

        controller.changeScale(to: 1)
        select("@1x", in: controller)
        #expect(controller.model.document.scale == 2)
        #expect(controller.statusBar.scaleButton.titleOfSelectedItem == "@2x")

        controller.cancelCrop(nil)
        #expect(controller.validateMenuItem(item))
        #expect(controller.statusBar.scaleButton.isEnabled)
    }

    @Test func popUpCommitsTextEditing() throws {
        let controller = makeController(Document(blankSize: CGSize(width: 400, height: 300), scale: 2))
        defer { controller.close() }
        controller.toolbar.activeTool = .text
        let view = controller.canvasView
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: view.convert(CGPoint(x: 50, y: 50), to: nil), modifierFlags: [], timestamp: 0,
                windowNumber: view.window?.windowNumber ?? 0, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
            type == .leftMouseDown ? view.mouseDown(with: event) : view.mouseUp(with: event)
        }
        let textView = try #require(view.textEditor.textView)
        textView.insertText("Hi", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(!controller.validateMenuItem(try imageMenuItem("Scale @1x")))
        #expect(controller.statusBar.scaleButton.isEnabled)

        select("@1x", in: controller)
        #expect(!view.textEditor.isEditing)
        #expect(controller.model.document.annotations.count == 1)
        #expect(controller.model.document.scale == 1)
    }

    /// Columns alternate black and white at 2×, so 1× output pixels are gray.
    private static func stripes() -> BaseImage {
        let width = 200, height = 100
        let pixels = (0..<(width * height)).map { index -> [UInt8] in
            index % 2 == 0 ? [0, 0, 0, 255] : [255, 255, 255, 255]
        }
        var data = pixels.flatMap { $0 }
        let image = data.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
        }
        return BaseImage(cgImage: image, scale: 2)
    }

    private func canvasBrightness(scale: CGFloat) throws -> (values: [CGFloat], backingScale: CGFloat) {
        var document = Document(image: Self.stripes())
        document.setScale(scale)
        let controller = makeController(document)
        defer { controller.close() }
        let window = try #require(controller.window)
        window.setContentSize(NSSize(width: 1000, height: 700))
        let content = try #require(window.contentView)
        content.layoutSubtreeIfNeeded()
        controller.scrollView.magnification = 2
        let rep = try #require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: rep)
        let pixelsPerPoint = CGFloat(rep.pixelsWide) / content.bounds.width
        let canvas = content.convert(controller.canvasView.bounds, from: controller.canvasView)
        let y = Int((content.bounds.height - canvas.midY) * pixelsPerPoint)
        let minX = Int(canvas.minX * pixelsPerPoint) + 4, maxX = Int(canvas.maxX * pixelsPerPoint) - 4
        let values = (minX..<maxX).map {
            rep.colorAt(x: $0, y: y)?.usingColorSpace(.sRGB)?.brightnessComponent ?? 0
        }
        return (values, window.backingScaleFactor)
    }

    /// At 200 % a 2× screen shows 4 device pixels per point: 2× output draws directly, 1× output shows its own pixels.
    @Test func canvasShowsOutputPixelsBelowScreenDensity() throws {
        let native = try canvasBrightness(scale: 2).values
        #expect(native.contains { $0 < 0.1 })
        #expect(native.contains { $0 > 0.9 })
        let (output, backingScale) = try canvasBrightness(scale: 1)
        if backingScale >= 2 {
            #expect(output.allSatisfy { $0 > 0.25 && $0 < 0.85 })
        } else {
            #expect(output.contains { $0 < 0.1 } && output.contains { $0 > 0.9 })
        }
    }
}
