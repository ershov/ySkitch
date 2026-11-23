import AppKit
import ImageIO
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct StatusBarTests {
    private func makeController() -> DocumentWindowController {
        DocumentWindowController(
            document: Document(blankSize: CGSize(width: 1440, height: 900), scale: 2), title: "Test")
    }

    @Test func showsSizeText() {
        let controller = makeController()
        defer { controller.close() }
        #expect(controller.statusBar.sizeLabel.stringValue == "2880×1800 px · 1440×900 pt · @2x")
    }

    @Test func zoomInButtonChangesMagnification() {
        let controller = makeController()
        defer { controller.close() }
        let before = controller.scrollView.magnification

        controller.statusBar.zoomInButton.performClick(nil)

        let after = controller.scrollView.magnification
        #expect(after > before)
        #expect(controller.statusBar.zoomLabel.stringValue == StatusText.zoom(after))
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
