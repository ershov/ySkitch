import CoreGraphics

public struct BaseImage: @unchecked Sendable, Equatable {
    public let cgImage: CGImage
    /// Pixels per point, ≥ 1.
    public let scale: CGFloat

    public init(cgImage: CGImage, scale: CGFloat = 1) {
        self.cgImage = cgImage
        self.scale = max(1, scale)
    }

    public var pixelSize: CGSize { CGSize(width: cgImage.width, height: cgImage.height) }
    public var pointSize: CGSize { CGSize(width: CGFloat(cgImage.width) / scale, height: CGFloat(cgImage.height) / scale) }

    public static func == (lhs: BaseImage, rhs: BaseImage) -> Bool {
        lhs.cgImage === rhs.cgImage && lhs.scale == rhs.scale
    }
}
