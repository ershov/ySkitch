import AppKit
import ImageIO
import UniformTypeIdentifiers
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct WindowRegistryTests {
    @Test func registersAndUnregistersWindows() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let first = registry.openBlank()
        let second = registry.openBlank()
        #expect(registry.controllers.count == 2)

        try #require(first.window).close()
        #expect(registry.controllers.count == 1)
        #expect(registry.controllers.first === second)

        try #require(second.window).close()
        #expect(registry.controllers.isEmpty)
    }

    @Test func windowsUseInjectedToolSettings() throws {
        let settings = ToolSettings.inMemory()
        let registry = WindowRegistry(toolSettings: settings)
        let controller = registry.openBlank()
        #expect(controller.toolbar.settings === settings)
        controller.toolbar.activeTool = .ellipse
        #expect(settings.preferences.lastTool == .ellipse)

        try #require(controller.window).close()
        let reopened = try #require(registry.reopenLastClosed())
        defer { reopened.close() }
        #expect(reopened.toolbar.settings === settings)
    }

    @Test func newWindowFitsLargeDocumentInViewport() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let controller = registry.show(Document(blankSize: CGSize(width: 8000, height: 8000), scale: 1), title: "Large")
        defer { controller.close() }
        let scrollView = controller.scrollView
        let content = NSScrollView.contentSize(
            forFrameSize: scrollView.frame.size, horizontalScrollerClass: nil, verticalScrollerClass: nil,
            borderType: scrollView.borderType, controlSize: .regular, scrollerStyle: scrollView.scrollerStyle)
        let size = try #require(scrollView.documentView).frame.size
        #expect(size.width * scrollView.magnification <= content.width + 1)
        #expect(size.height * scrollView.magnification <= content.height + 1)
    }

    @Test func newWindowShowsMarginAroundSmallDocument() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let controller = registry.show(Document(blankSize: CGSize(width: 400, height: 300), scale: 1), title: "Small")
        defer { controller.close() }
        let scrollView = controller.scrollView
        let content = NSScrollView.contentSize(
            forFrameSize: scrollView.frame.size, horizontalScrollerClass: nil, verticalScrollerClass: nil,
            borderType: scrollView.borderType, controlSize: .regular, scrollerStyle: scrollView.scrollerStyle)
        let size = try #require(scrollView.documentView).frame.size
        #expect(scrollView.magnification == CGFloat(1))
        #expect((content.width - size.width) / 2 >= WindowSizing.margin - 1)
        #expect((content.height - size.height) / 2 >= WindowSizing.margin - 1)
    }

    @Test func reopenedWindowKeepsStoredMagnification() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let original = registry.show(Document(blankSize: CGSize(width: 8000, height: 8000), scale: 1), title: "Large")
        original.scrollView.magnification = 0.5
        try #require(original.window).close()
        let reopened = try #require(registry.reopenLastClosed())
        defer { reopened.close() }
        #expect(reopened.scrollView.magnification == CGFloat(0.5))
    }

    private func pngData(dpi: Double) -> Data {
        let ctx = CGContext(
            data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        let properties: [CFString: Any] = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi]
        CGImageDestinationAddImage(destination, ctx.makeImage()!, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: .init("ySkitch.tests.\(UUID().uuidString)"))
    }

    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func openFromPasteboardIgnoresNonImageFileForTitle() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let text = dir.appending(path: "notes.txt")
        try Data("x".utf8).write(to: text)
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects([text as NSURL])
        pasteboard.setData(pngData(dpi: 72), forType: .png)

        let controller = registry.openFromPasteboard(pasteboard)
        defer { controller.close() }
        #expect(controller.window?.title.hasPrefix("ySkitch ") == true)
    }

    @Test func openFromPasteboardTitlesFromLoadedFile() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let broken = dir.appending(path: "Broken.png")
        let good = dir.appending(path: "Good.png")
        try Data("not a png".utf8).write(to: broken)
        try pngData(dpi: 72).write(to: good)
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects([broken as NSURL, good as NSURL])

        let controller = registry.openFromPasteboard(pasteboard)
        defer { controller.close() }
        #expect(controller.window?.title == "Good")
    }

    @Test func openFromPasteboardWithImage() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setData(pngData(dpi: 144), forType: .png)

        let controller = registry.openFromPasteboard(pasteboard)
        defer { controller.close() }
        #expect(registry.controllers.count == 1)
        #expect(controller.model.document.scale == 2)
        #expect(controller.window?.title.hasPrefix("ySkitch ") == true)
        #expect(controller.defaultFileName == controller.window?.title)
    }

    @Test func openFromEmptyPasteboardIsBlank() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()

        let controller = registry.openFromPasteboard(pasteboard)
        defer { controller.close() }
        let document = controller.model.document
        #expect(document.base == nil)
        #expect(document.imageRect.size == CGSize(width: 1024, height: 768))
    }

    @Test func openURLUsesFileName() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "My Shot.png")
        try pngData(dpi: 72).write(to: url)

        let registry = WindowRegistry(toolSettings: .inMemory())
        let controller = try registry.open(url: url)
        defer { controller.close() }
        #expect(controller.window?.title == "My Shot")
    }

    @Test func openNonImageThrows() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "notes.txt")
        try Data("hello".utf8).write(to: url)

        let registry = WindowRegistry(toolSettings: .inMemory())
        #expect(throws: (any Error).self) { try registry.open(url: url) }
        #expect(registry.controllers.isEmpty)
    }
}
