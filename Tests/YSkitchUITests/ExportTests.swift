import AppKit
import ImageIO
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct ExportTests {
    private func makeController(scale: CGFloat) -> DocumentWindowController {
        DocumentWindowController(
            document: Document(blankSize: CGSize(width: 50, height: 30), scale: scale), title: "Test",
            toolSettings: .inMemory())
    }

    @Test func copyImageWritesPNGAndTIFF() throws {
        let controller = makeController(scale: 2)
        defer { controller.close() }
        let pasteboard = NSPasteboard(name: .init("ySkitch.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        controller.copyImage(to: pasteboard)

        #expect(pasteboard.data(forType: .png) != nil)
        #expect(pasteboard.data(forType: .tiff) != nil)
        let image = try #require(PasteboardImageReader.read(from: pasteboard))
        #expect(image.cgImage.width == 100)
        #expect(image.cgImage.height == 60)
        #expect(image.scale == 2)
    }

    @Test func writeProducesDecodablePNG() throws {
        let controller = makeController(scale: 2)
        defer { controller.close() }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("out.png")

        try controller.write(to: url)

        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 100)
        #expect(image.height == 60)
    }

    @Test func preferencesRoundTripLastSaveFolder() {
        let store = InMemoryPreferencesStore()
        let preferences = Preferences(store: store)
        #expect(preferences.lastSaveFolder == nil)

        let folder = URL(fileURLWithPath: "/tmp/ySkitch-folder", isDirectory: true)
        preferences.lastSaveFolder = folder
        #expect(Preferences(store: store).lastSaveFolder?.path == folder.path)
    }
}
