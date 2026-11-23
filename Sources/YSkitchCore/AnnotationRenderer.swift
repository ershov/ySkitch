import CoreGraphics

public enum AnnotationRenderer {
    public static func draw(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        let style = annotation.style
        let path: CGPath
        let lineCap: CGLineCap
        let lineJoin: CGLineJoin
        switch annotation.shape {
        case .rectangle(let rect):
            path = CGPath(rect: rect, transform: nil)
            lineCap = .butt
            lineJoin = .miter
        case .roundedRectangle(let rect):
            let radius = ShapeGeometry.cornerRadius(thickness: style.thickness, rect: rect)
            path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            lineCap = .butt
            lineJoin = .round
        case .ellipse(let rect):
            path = CGPath(ellipseIn: rect, transform: nil)
            lineCap = .butt
            lineJoin = .round
        case .line(let start, let end):
            let line = CGMutablePath()
            line.move(to: start)
            line.addLine(to: end)
            path = line
            lineCap = .round
            lineJoin = .round
        case .arrow(let tail, let head):
            OutlinedDrawing.fill(
                ArrowGeometry.path(tail: tail, head: head, thickness: style.thickness),
                color: style.color.cgColor,
                outlineWidth: OutlineStyle.whiteWidth(forLineWidth: style.thickness),
                in: context)
            return
        }
        OutlinedDrawing.stroke(
            path,
            lineWidth: style.thickness,
            color: style.color.cgColor,
            lineCap: lineCap,
            lineJoin: lineJoin,
            in: context
        )
    }
}
