import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import YSkitchUI

@MainActor
struct PasteboardImageReaderTests {
    private func pngData(dpi: Double?) -> Data {
        let ctx = CGContext(
            data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        var properties: [CFString: Any] = [:]
        if let dpi {
            properties[kCGImagePropertyDPIWidth] = dpi
            properties[kCGImagePropertyDPIHeight] = dpi
        }
        CGImageDestinationAddImage(destination, ctx.makeImage()!, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: .init("ySkitch.tests.\(UUID().uuidString)"))
    }

    @Test func pngDataKeepsDPIScale() throws {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setData(pngData(dpi: 144), forType: .png)
        let pasted = try #require(PasteboardImageReader.read(from: pasteboard))
        let image = pasted.image
        #expect(image.scale == 2)
        #expect(image.cgImage.width == 4)
        #expect(pasted.sourceURL == nil)
    }

    @Test func fileURLLoads() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("image.png")
        try pngData(dpi: nil).write(to: url)

        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
        let pasted = try #require(PasteboardImageReader.read(from: pasteboard))
        let image = pasted.image
        #expect(image.scale == 1)
        #expect(image.cgImage.height == 2)
        #expect(pasted.sourceURL == url)
    }

    @Test func skipsUndecodableAndNonImageFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let text = dir.appendingPathComponent("a.txt")
        let broken = dir.appendingPathComponent("b.png")
        let good = dir.appendingPathComponent("c.png")
        try Data("x".utf8).write(to: text)
        try Data("not a png".utf8).write(to: broken)
        try pngData(dpi: nil).write(to: good)

        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.writeObjects([text as NSURL, broken as NSURL, good as NSURL])
        #expect(PasteboardImageReader.read(from: pasteboard)?.sourceURL == good)
    }

    @Test func plainStringIsNotAnImage() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)
        #expect(PasteboardImageReader.read(from: pasteboard) == nil)
    }
}
