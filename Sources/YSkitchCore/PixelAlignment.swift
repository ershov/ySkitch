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
}
