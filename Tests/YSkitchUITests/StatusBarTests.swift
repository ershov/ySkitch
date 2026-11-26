import AppKit
import ImageIO
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct StatusBarTests {
    private func makeController() -> DocumentWindowController {
        DocumentWindowController(
            document: Document(blankSize: CGSize(width: 1440, height: 900), scale: 2), title: "Test",
            toolSettings: .inMemory())
    }

    @Test func showsSizeText() {
        let controller = makeController()
        defer { controller.close() }
        #expect(controller.statusBar.infoLabel.stringValue == "2880×1800 px · 1440×900 pt")
        #expect(controller.statusBar.scaleButton.titleOfSelectedItem == "@2x")
    }

    @Test func zoomInButtonChangesMagnification() {
        let controller = makeController()
        defer { controller.close() }
        let before = controller.scrollView.magnification

        controller.statusBar.zoomInButton.performClick(nil)

        let after = controller.scrollView.magnification
        #expect(after > before)
        #expect(controller.statusBar.zoomButton.attributedTitle.string == StatusText.zoom(after))
    }

    @Test func zoomSliderZoomsAndTurnsFitModeOff() {
        let controller = makeController()
        defer { controller.close() }
        #expect(controller.scrollView.isFitMode)
        let panel = ZoomSliderPanel(magnification: controller.scrollView.magnification)
        panel.onZoom = { [weak controller] in controller?.statusBar.onZoomTo?($0) }

        panel.setPosition(1)

        #expect(abs(controller.scrollView.magnification - 5) < 1e-6)
        #expect(!controller.scrollView.isFitMode)
        #expect(panel.position == 1)
        #expect(controller.statusBar.zoomButton.attributedTitle.string == StatusText.zoom(controller.scrollView.magnification))

        panel.resetToActualSize()

        #expect(controller.scrollView.magnification == 1)
        #expect(panel.position == 0.5)
    }

    @Test func zoomSliderPinsOutOfRangeZoom() {
        let panel = ZoomSliderPanel(magnification: 16)
        #expect(panel.position == 1)
        #expect(panel.shownMagnification == 16)
    }

    @Test func pasteboardItemCarriesFileAndPNG() throws {
        let png = ImageExporter.pngData(Document(blankSize: CGSize(width: 10, height: 5), scale: 2))
        let item = try DragHandleView.makePasteboardItem(png: png, fileName: "shot")

        let urlString = try #require(item.string(forType: .fileURL))
        let url = try #require(URL(string: urlString))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(url.lastPathComponent == "shot.png")
        #expect(item.data(forType: .png) == png)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 20)
        #expect(image.height == 10)
    }
}

@MainActor
struct MinimumWindowSizeTests {
    private func makeController(size: CGSize) -> DocumentWindowController {
        DocumentWindowController(
            document: Document(blankSize: size, scale: 2), title: "Test", toolSettings: .inMemory())
    }

    @Test func minimumCoversToolbarAndStatusBar() {
        let controller = makeController(size: CGSize(width: 800, height: 600))
        defer { controller.close() }
        let minimum = controller.window!.contentMinSize

        #expect(minimum.height >= ToolbarView.toolsColumnHeight + 2 * ToolbarView.padding + StatusBarView.height)
        #expect(minimum.width >= ToolbarView.width + DocumentWindowController.minimumCanvasWidth)
        #expect(minimum.width >= controller.statusBar.minimumWidth)
    }

    @Test func tinyImageOpensAtMinimum() {
        let controller = makeController(size: CGSize(width: 10, height: 10))
        defer { controller.close() }
        let window = controller.window!
        let content = window.contentRect(forFrameRect: window.frame).size

        #expect(content.width >= window.contentMinSize.width)
        #expect(content.height >= window.contentMinSize.height)
    }

    @Test func statusBarSubviewsDoNotOverlapAtMinimumWidth() {
        let statusBar = StatusBarView()
        statusBar.update(info: "Arrow · (10000, 10000) → (20000, 20000) · 14142 px · 45° · 4 pt")
        statusBar.update(scale: 2)
        statusBar.update(magnification: 1)
        statusBar.frame = NSRect(x: 0, y: 0, width: statusBar.minimumWidth, height: StatusBarView.height)
        statusBar.layoutSubtreeIfNeeded()

        let handle = statusBar.dragHandle.frame
        let label = statusBar.infoLabel.frame
        let scale = statusBar.scaleButton.alignmentRect(forFrame: statusBar.scaleButton.frame)
        let controls = statusBar.zoomInButton.frame.union(statusBar.actualSizeButton.frame)
        let controlsInBar = statusBar.convert(controls, from: statusBar.actualSizeButton.superview)
        #expect(label.maxX <= scale.minX)
        #expect(scale.width >= statusBar.scaleButton.intrinsicContentSize.width)
        #expect(scale.maxX <= handle.minX)
        #expect(controlsInBar.minX >= handle.maxX)
        #expect(controlsInBar.maxX <= statusBar.bounds.maxX)
    }
}
