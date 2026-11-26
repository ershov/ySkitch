import CoreGraphics

/// Where pasted annotations land: at the anchor, kept inside the canvas, and cascaded
/// when they would coincide with the original or an earlier paste.
public enum PastePlacement {
    public static let step = CGVector(dx: 10, dy: 10)
    public static let snapDistance: CGFloat = 10

    /// `snapped` is the offset before the cascade; the caller records it as a snap target.
    public static func offset(
        for pasted: [Annotation], anchor: CGPoint, canvas: CGRect, existing: [AnnotationShape],
        snapTargets: [CGVector]
    ) -> (snapped: CGVector, final: CGVector) {
        guard let first = pasted.first else { return (.zero, .zero) }
        let geometry = pasted.dropFirst().reduce(first.bounds) { $0.union($1.bounds) }
        let render = pasted.dropFirst().reduce(first.renderBounds) { $0.union($1.renderBounds) }

        var dx = anchor.x - geometry.midX
        var dy = anchor.y - geometry.midY
        dx = clamped(dx, span: render.minX...render.maxX, within: canvas.minX...canvas.maxX)
        dy = clamped(dy, span: render.minY...render.maxY, within: canvas.minY...canvas.maxY)

        var snapped = CGVector(dx: dx, dy: dy)
        if let target = ([.zero] + snapTargets).first(where: {
            abs($0.dx - dx) < snapDistance && abs($0.dy - dy) < snapDistance
        }) {
            snapped = target
        }

        var final = snapped
        while pasted.contains(where: { existing.contains($0.translated(by: final).shape) }) {
            final = CGVector(dx: final.dx + step.dx, dy: final.dy + step.dy)
        }
        return (snapped, final)
    }

    /// Adjusts `delta` so the span fits in `limit`; a span wider than the limit is centered on it.
    private static func clamped(_ delta: CGFloat, span: ClosedRange<CGFloat>, within limit: ClosedRange<CGFloat>)
        -> CGFloat
    {
        if span.upperBound - span.lowerBound > limit.upperBound - limit.lowerBound {
            return (limit.lowerBound + limit.upperBound) / 2 - (span.lowerBound + span.upperBound) / 2
        }
        return min(max(delta, limit.lowerBound - span.lowerBound), limit.upperBound - span.upperBound)
    }
}
