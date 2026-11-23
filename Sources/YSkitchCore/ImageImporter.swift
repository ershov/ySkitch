import CoreGraphics
import Foundation
import ImageIO

public enum ImageImportError: Error {
    case unreadable
    case noImage
}

public enum ImageImporter {
    public static func load(url: URL) throws -> BaseImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw ImageImportError.unreadable }
        return try load(source: source)
    }

    public static func load(data: Data) throws -> BaseImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw ImageImportError.unreadable }
        return try load(source: source)
    }

    public static func scale(pixelWidth: Int, pointWidth: CGFloat) -> CGFloat {
        guard pointWidth > 0 else { return 1 }
        return max(1, (CGFloat(pixelWidth) / pointWidth).rounded())
    }

    public static func opaqueOnWhite(_ image: CGImage) -> CGImage {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return image
        default:
            break
        }
        let space: CGColorSpace
        if let own = image.colorSpace, own.model == .rgb {
            space = own
        } else {
            space = CGColorSpace(name: CGColorSpace.sRGB)!
        }
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return image }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage() ?? image
    }

    private static func load(source: CGImageSource) throws -> BaseImage {
        guard CGImageSourceGetCount(source) > 0 else { throw ImageImportError.noImage }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1

        let decoded: CGImage?
        if orientation != 1 {
            let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
            let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            ]
            decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        } else {
            decoded = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        guard let decoded else { throw ImageImportError.noImage }

        let dpi = (properties?[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 72
        let scale = max(1, CGFloat((dpi / 72).rounded()))
        return BaseImage(cgImage: opaqueOnWhite(decoded), scale: scale)
    }
}
