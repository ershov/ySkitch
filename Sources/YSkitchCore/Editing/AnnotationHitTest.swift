import CoreGraphics
import Foundation

public enum AnnotationHitTest {
    /// `tolerance` is in points; outline-only shapes are hit on their stroke, not in their interior.
    public static func contains(_ annotation: Annotation, point: CGPoint, tolerance: CGFloat) -> Bool {
        let thickness = annotation.style.thickness
        switch annotation.shape {
        case .pixelate(let rect):
            return rect.contains(point)
        case .arrow(let tail, let head):
            return filled(ArrowGeometry.path(tail: tail, head: head, thickness: thickness), point, tolerance)
        case .text:
            return annotation.bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .rectangle, .roundedRectangle, .ellipse, .line, .pen, .highlighter:
            guard let stroke = annotation.stroke else { return false }
            return stroke.path
                .copy(strokingWithWidth: thickness + 2 * tolerance, lineCap: stroke.cap,
                      lineJoin: stroke.join, miterLimit: 10)
                .contains(point)
        }
    }

    /// The visually topmost annotation that contains `point`.
    public static func topmost(in document: Document, at point: CGPoint, tolerance: CGFloat) -> UUID? {
        document.annotationsInVisualOrder.last { contains($0, point: point, tolerance: tolerance) }?.id
    }

    private static func filled(_ path: CGPath, _ point: CGPoint, _ tolerance: CGFloat) -> Bool {
        if path.contains(point) { return true }
        guard tolerance > 0 else { return false }
        return path.copy(strokingWithWidth: 2 * tolerance, lineCap: .round, lineJoin: .round, miterLimit: 10)
            .contains(point)
    }
}
