import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import YSkitchCore

private func encode(_ image: CGImage, type: UTType, properties: [CFString: Any] = [:]) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    precondition(CGImageDestinationFinalize(destination))
    return data as Data
}

@Suite struct ImageImporterTests {
    private let sample = makeImage(width: 4, height: 2, pixels: Array(repeating: red, count: 8))

    private func withTempFile<T>(_ data: Data, ext: String, _ body: (URL) throws -> T) throws -> T {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("image.\(ext)")
        try data.write(to: url)
        return try body(url)
    }

    @Test func dpiToScale() throws {
        let cases: [(dpi: Double, scale: CGFloat)] = [(72, 1), (96, 1), (144, 2)]
        for (dpi, scale) in cases {
            let data = encode(sample, type: .png, properties: [
                kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi,
            ])
            let image = try ImageImporter.load(data: data)
            #expect(image.scale == scale)
            #expect(image.cgImage.width == 4)
            #expect(image.cgImage.height == 2)
        }
    }

    @Test func missingDPIMeansScaleOne() throws {
        let image = try ImageImporter.load(data: encode(sample, type: .png))
        #expect(image.scale == 1)
    }

    @Test func loadsFromFile() throws {
        let image = try withTempFile(encode(sample, type: .png), ext: "png") { try ImageImporter.load(url: $0) }
        #expect(image.cgImage.width == 4)
    }

    @Test func transparencyCompositesOnWhite() throws {
        let source = makeImage(width: 3, height: 1, pixels: [
            Pixel(r: 0, g: 0, b: 0, a: 0),
            Pixel(r: 0, g: 0, b: 0, a: 128),
            red,
        ])
        let image = try ImageImporter.load(data: encode(source, type: .png))
        #expect(image.cgImage.alphaInfo == .noneSkipLast)
        let px = readPixels(image.cgImage).pixel
        #expect(px(0, 0) == white)
        let grey = px(1, 0)
        #expect(abs(Int(grey.r) - 127) <= 3)
        #expect(abs(Int(grey.g) - 127) <= 3)
        #expect(abs(Int(grey.b) - 127) <= 3)
        #expect(px(2, 0) == red)
    }

    @Test func jpegAndTiffLoad() throws {
        for type in [UTType.jpeg, .tiff] {
            let image = try ImageImporter.load(data: encode(sample, type: type))
            #expect(image.cgImage.width == 4)
            #expect(image.cgImage.height == 2)
        }
    }

    @Test func orientationIsApplied() throws {
        let data = encode(sample, type: .jpeg, properties: [kCGImagePropertyOrientation: 6])
        let image = try ImageImporter.load(data: data)
        #expect(image.cgImage.width == 2)
        #expect(image.cgImage.height == 4)
    }

    @Test func garbageThrows() {
        #expect(throws: ImageImportError.self) { try ImageImporter.load(data: Data("not an image".utf8)) }
        #expect(throws: ImageImportError.self) { try ImageImporter.load(url: URL(fileURLWithPath: "/nonexistent/x.png")) }
    }

    @Test func scaleFromPointWidth() {
        #expect(ImageImporter.scale(pixelWidth: 200, pointWidth: 100) == 2)
        #expect(ImageImporter.scale(pixelWidth: 100, pointWidth: 100) == 1)
        #expect(ImageImporter.scale(pixelWidth: 50, pointWidth: 100) == 1)
        #expect(ImageImporter.scale(pixelWidth: 300, pointWidth: 100) == 3)
        #expect(ImageImporter.scale(pixelWidth: 100, pointWidth: 0) == 1)
    }
}
