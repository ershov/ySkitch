import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import YSkitchCore

@Suite struct ImageExporterTests {
    private func decode(_ data: Data) throws -> (CGImage, [CFString: Any]) {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (image, properties)
    }

    @Test func scaledDocument() throws {
        var document = Document(blankSize: CGSize(width: 50, height: 30), scale: 2)
        document.annotations = []
        let (image, properties) = try decode(ImageExporter.pngData(document))
        #expect(image.width == 100)
        #expect(image.height == 60)
        #expect(properties[kCGImagePropertyDPIWidth] as? Double == 144)
        #expect(properties[kCGImagePropertyDPIHeight] as? Double == 144)
    }

    @Test func unscaledDocument() throws {
        let document = Document(blankSize: CGSize(width: 50, height: 30), scale: 1)
        let (_, properties) = try decode(ImageExporter.pngData(document))
        #expect(properties[kCGImagePropertyDPIWidth] as? Double == 72)
    }

    @Test func noMetadataAndNoAlpha() throws {
        let document = Document(blankSize: CGSize(width: 10, height: 10), scale: 1)
        let (_, properties) = try decode(ImageExporter.pngData(document))
        // ImageIO synthesizes structural Exif keys when decoding; nothing else may be present.
        let exif = (properties[kCGImagePropertyExifDictionary] as? [CFString: Any]) ?? [:]
        let structural: Set<String> = [
            kCGImagePropertyExifColorSpace, kCGImagePropertyExifPixelXDimension,
            kCGImagePropertyExifPixelYDimension,
        ].map { $0 as String }.reduce(into: []) { $0.insert($1) }
        #expect(Set(exif.keys.map { $0 as String }).isSubset(of: structural))
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(properties[kCGImagePropertyIPTCDictionary] == nil)
        #expect(properties[kCGImagePropertyHasAlpha] as? Bool != true)
    }

    @Test func topLeftPixelMatchesRender() throws {
        let document = Document(blankSize: CGSize(width: 10, height: 10), scale: 1)
        let (image, _) = try decode(ImageExporter.pngData(document))
        let expected = readPixels(Renderer.flatten(document)).pixel(0, 0)
        #expect(readPixels(image).pixel(0, 0) == expected)
    }
}
