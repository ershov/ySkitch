import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import YSkitchCore

private func canEncode(_ type: UTType) -> Bool {
    let ids = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
    return ids.contains(type.identifier)
}

private func encode(_ images: [CGImage], type: UTType) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, images.count, nil)!
    for image in images { CGImageDestinationAddImage(destination, image, nil) }
    precondition(CGImageDestinationFinalize(destination))
    return data as Data
}

private func solid(_ pixel: Pixel, width: Int = 64, height: Int = 32) -> CGImage {
    makeImage(width: width, height: height, pixels: Array(repeating: pixel, count: width * height))
}

private func close(_ a: Pixel, _ b: Pixel, tolerance: Int) -> Bool {
    abs(Int(a.r) - Int(b.r)) <= tolerance && abs(Int(a.g) - Int(b.g)) <= tolerance
        && abs(Int(a.b) - Int(b.b)) <= tolerance
}

@Suite struct ImageImporterFormatTests {
    private func withTempFile<T>(_ data: Data, ext: String, _ body: (URL) throws -> T) throws -> T {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("image.\(ext)")
        try data.write(to: url)
        return try body(url)
    }

    private func expectSolid(_ image: BaseImage, _ expected: Pixel, tolerance: Int) {
        #expect(image.cgImage.width == 64)
        #expect(image.cgImage.height == 32)
        #expect(image.scale == 1)
        let px = readPixels(image.cgImage).pixel
        for (x, y) in [(0, 0), (32, 16), (63, 31)] {
            #expect(close(px(x, y), expected, tolerance: tolerance))
        }
    }

    @Test(.enabled(if: canEncode(.gif)))
    func gifLoadsFirstFrame() throws {
        let data = encode([solid(red), solid(blue)], type: .gif)
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        #expect(CGImageSourceGetCount(source) == 2)
        let image = try withTempFile(data, ext: "gif") { try ImageImporter.load(url: $0) }
        expectSolid(image, red, tolerance: 8)
    }

    @Test(.enabled(if: canEncode(.bmp)))
    func bmpRoundTrip() throws {
        let image = try withTempFile(encode([solid(red)], type: .bmp), ext: "bmp") { try ImageImporter.load(url: $0) }
        expectSolid(image, red, tolerance: 0)
    }

    @Test(.enabled(if: canEncode(.heic)))
    func heicRoundTrip() throws {
        let image = try withTempFile(encode([solid(red)], type: .heic), ext: "heic") { try ImageImporter.load(url: $0) }
        expectSolid(image, red, tolerance: 24)
    }

    @Test(arguments: [UTType.png, .jpeg, .tiff, .bmp, .gif, .heic])
    func decodedImageSurvivesFileDeletion(_ type: UTType) throws {
        guard canEncode(type), let ext = type.preferredFilenameExtension else { return }
        let image = try withTempFile(encode([solid(red)], type: type), ext: ext) { try ImageImporter.load(url: $0) }
        expectSolid(image, red, tolerance: 24)
    }

    @Test(.enabled(if: canEncode(.webP)))
    func webpRoundTrip() throws {
        let image = try withTempFile(encode([solid(red)], type: .webP), ext: "webp") { try ImageImporter.load(url: $0) }
        expectSolid(image, red, tolerance: 24)
    }
}
