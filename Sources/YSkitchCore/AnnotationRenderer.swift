import CoreGraphics

public enum AnnotationRenderer {
    public static func draw(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        let style = annotation.style
        let path: CGPath
        let lineJoin: CGLineJoin
        switch annotation.shape {
        case .rectangle(let rect):
            path = CGPath(rect: rect, transform: nil)
            lineJoin = .miter
        case .roundedRectangle(let rect):
            let radius = ShapeGeometry.cornerRadius(thickness: style.thickness, rect: rect)
            path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            lineJoin = .round
        case .ellipse(let rect):
            path = CGPath(ellipseIn: rect, transform: nil)
            lineJoin = .round
        }
        OutlinedDrawing.stroke(
            path,
            lineWidth: style.thickness,
            color: style.color.cgColor,
            lineCap: .butt,
            lineJoin: lineJoin,
            in: context
        )
    }
}
