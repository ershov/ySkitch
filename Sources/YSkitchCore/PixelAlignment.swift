import CoreGraphics

public enum PixelAlignment {
    /// Clip-view origin centering a document in a larger viewport. The document's distance from the
    /// viewport edge, `documentMin - origin`, is snapped to whole device pixels.
    /// Lengths are in document points; `pixelsPerPoint` is magnification × backing scale.
    public static func centeredOrigin(
        documentMin: CGFloat, documentLength: CGFloat, viewportLength: CGFloat, pixelsPerPoint: CGFloat
    ) -> CGFloat {
        let offset = (viewportLength - documentLength) / 2
        guard pixelsPerPoint > 0, pixelsPerPoint.isFinite else { return documentMin - offset }
        return documentMin - (offset * pixelsPerPoint).rounded() / pixelsPerPoint
    }

    /// The largest rect inside `rect` whose edges lie on whole device pixels.
    /// `userToDevice` must be axis-aligned (scale, flip, translation).
    public static func inwardSnapped(_ rect: CGRect, userToDevice: CGAffineTransform) -> CGRect {
        let device = rect.applying(userToDevice)
        let tolerance = 1e-6
        let minX = (device.minX - tolerance).rounded(.up), maxX = (device.maxX + tolerance).rounded(.down)
        let minY = (device.minY - tolerance).rounded(.up), maxY = (device.maxY + tolerance).rounded(.down)
        guard maxX > minX, maxY > minY else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            .applying(userToDevice.inverted())
    }
}
