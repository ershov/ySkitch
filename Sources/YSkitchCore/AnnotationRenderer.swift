import CoreGraphics

public enum AnnotationRenderer {
    public static func draw(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        switch annotation.shape {
        case .rectangle(let rect):
            context.setStrokeColor(annotation.style.color.cgColor)
            context.setLineWidth(annotation.style.thickness)
            context.setLineJoin(.miter)
            context.stroke(rect)
        }
    }
}
