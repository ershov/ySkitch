import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageExporter {
    public static func pngData(_ document: Document) -> Data {
        let image = Renderer.flatten(document)
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        let dpi = 72 * Double(document.scale)
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
