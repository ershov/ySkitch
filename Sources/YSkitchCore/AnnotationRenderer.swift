import CoreGraphics

public enum AnnotationRenderer {
    public static func draw(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        let style = annotation.style
        switch annotation.shape {
        case .arrow(let tail, let head):
            OutlinedDrawing.fill(
                ArrowGeometry.path(tail: tail, head: head, thickness: style.thickness),
                color: style.color.cgColor,
                outlineWidth: OutlineStyle.whiteWidth(forLineWidth: style.thickness),
                in: context)
        case .highlighter:
            if let stroke = annotation.stroke { drawHighlighter(stroke.path, style: style, in: context) }
        case .text(let content):
            drawText(content, style: style, in: context)
        case .pixelate:
            return
        case .rectangle, .roundedRectangle, .ellipse, .line, .pen:
            guard let stroke = annotation.stroke else { return }
            OutlinedDrawing.stroke(
                stroke.path,
                lineWidth: style.thickness,
                color: style.color.cgColor,
                lineCap: stroke.cap,
                lineJoin: stroke.join,
                in: context
            )
        }
    }

    private static func drawText(_ content: TextContent, style: AnnotationStyle, in context: CGContext) {
        guard let path = TextLayout.path(of: content, fontSize: style.thickness) else { return }
        OutlinedDrawing.fill(
            path, color: style.color.cgColor,
            outlineWidth: TextStyle.outlineWidth(fontSize: style.thickness), in: context)
    }

    private static func drawHighlighter(_ path: CGPath, style: AnnotationStyle, in context: CGContext) {
        context.setAlpha(HighlighterStyle.opacity)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setStrokeColor(style.color.cgColor)
        context.setLineWidth(style.thickness)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addPath(path)
        context.strokePath()
        context.endTransparencyLayer()
    }
}

extension Annotation {
    /// Centerline path of shapes drawn as a stroke of the style's thickness.
    var stroke: (path: CGPath, cap: CGLineCap, join: CGLineJoin)? {
        switch shape {
        case .rectangle(let rect):
            return (CGPath(rect: rect, transform: nil), .butt, .miter)
        case .roundedRectangle(let rect):
            let radius = ShapeGeometry.cornerRadius(thickness: style.thickness, rect: rect)
            return (CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil), .butt, .round)
        case .ellipse(let rect):
            return (CGPath(ellipseIn: rect, transform: nil), .butt, .round)
        case .line(let start, let end):
            let line = CGMutablePath()
            line.move(to: start)
            line.addLine(to: end)
            return (line, .round, .round)
        case .pen(let points), .highlighter(let points):
            return (StrokeSmoothing.path(points), .round, .round)
        case .arrow, .text, .pixelate:
            return nil
        }
    }
}
