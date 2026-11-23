import CoreGraphics

public enum AnnotationRenderer {
    public static func draw(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        switch annotation.shape {
        case .rectangle(let rect):
            OutlinedDrawing.stroke(
                CGPath(rect: rect, transform: nil),
                lineWidth: annotation.style.thickness,
                color: annotation.style.color.cgColor,
                lineCap: .butt,
                lineJoin: .miter,
                in: context
            )
        }
    }
}
