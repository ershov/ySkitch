import AppKit
import ImageIO
import UniformTypeIdentifiers
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct WindowRegistryTests {
    @Test func registersAndUnregistersWindows() throws {
        let registry = WindowRegistry()
        let first = registry.openBlank()
        let second = registry.openBlank()
        #expect(registry.controllers.count == 2)

        try #require(first.window).close()
        #expect(registry.controllers.count == 1)
        #expect(registry.controllers.first === second)

        try #require(second.window).close()
        #expect(registry.controllers.isEmpty)
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

    @Test func openFromPasteboardWithImage() throws {
        let registry = WindowRegistry()
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
        let registry = WindowRegistry()
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

        let registry = WindowRegistry()
        let controller = try registry.open(url: url)
        defer { controller.close() }
        #expect(controller.window?.title == "My Shot")
    }

    @Test func openNonImageThrows() throws {
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "notes.txt")
        try Data("hello".utf8).write(to: url)

        let registry = WindowRegistry()
        #expect(throws: (any Error).self) { try registry.open(url: url) }
        #expect(registry.controllers.isEmpty)
    }
}
