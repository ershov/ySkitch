import CoreGraphics

/// Geometry shown in the status bar, in document coordinates.
public enum StatusGeometry: Equatable, Sendable {
    /// Line, arrow or straight stroke, start (tail) to end (head).
    case segment(name: String, from: CGPoint, to: CGPoint, thickness: CGFloat)
    /// `thickness` is nil for kinds without a size, e.g. a crop rect or a multi-selection.
    case box(name: String, from: CGPoint, to: CGPoint, thickness: CGFloat?)

    public init(_ annotation: Annotation) {
        let name = annotation.shape.tool.name
        let thickness = annotation.style.thickness
        if let start = annotation.endpoint(.start), let end = annotation.endpoint(.end) {
            self = .segment(name: name, from: start, to: end, thickness: thickness)
        } else {
            self = .box(rect: annotation.bounds, name: name, thickness: thickness)
        }
    }

    /// Nil for an empty selection; several annotations show their count and the union of their bounds.
    public init?(selection annotations: [Annotation]) {
        guard let first = annotations.first else { return nil }
        guard annotations.count > 1 else { self.init(first); return }
        let union = annotations.dropFirst().reduce(first.bounds) { $0.union($1.bounds) }
        self = .box(rect: union, name: "\(annotations.count) objects", thickness: nil)
    }

    /// Top-left to bottom-right.
    public static func box(rect: CGRect, name: String, thickness: CGFloat?) -> StatusGeometry {
        .box(name: name, from: CGPoint(x: rect.minX, y: rect.minY), to: CGPoint(x: rect.maxX, y: rect.maxY), thickness: thickness)
    }
}
