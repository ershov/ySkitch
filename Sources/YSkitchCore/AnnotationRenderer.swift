import CoreGraphics

public enum AnnotationRenderer {
    public static func draw(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        let style = annotation.style
        switch annotation.shape {
        case .arrow(let tail, let head):
            let path = ArrowGeometry.path(tail: tail, head: head, thickness: style.thickness)
            if OutlineStyle.outlinesShapes {
                OutlinedDrawing.fill(
                    path, color: style.color.cgColor,
                    outlineWidth: OutlineStyle.whiteWidth(forLineWidth: style.thickness), in: context)
            } else {
                context.setFillColor(style.color.cgColor)
                context.addPath(path)
                context.fillPath()
            }
        case .highlighter:
            drawHighlighters([annotation], in: context)
        case .text(let content):
            drawText(content, style: style, in: context)
        case .pixelate:
            return
        case .rectangle, .roundedRectangle, .ellipse, .line, .pen:
            guard let stroke = annotation.stroke else { return }
            if OutlineStyle.outlinesShapes {
                OutlinedDrawing.stroke(
                    stroke.path, lineWidth: style.thickness, color: style.color.cgColor,
                    lineCap: stroke.cap, lineJoin: stroke.join, in: context)
            } else {
                context.setStrokeColor(style.color.cgColor)
                context.setLineWidth(style.thickness)
                context.setLineCap(stroke.cap)
                context.setLineJoin(stroke.join)
                context.addPath(stroke.path)
                context.strokePath()
            }
        }
    }

    private static func drawText(_ content: TextContent, style: AnnotationStyle, in context: CGContext) {
        guard let path = TextLayout.path(of: content, fontSize: style.thickness) else { return }
        OutlinedDrawing.fill(
            path, color: style.color.cgColor,
            outlineWidth: TextStyle.outlineWidth(fontSize: style.thickness), in: context)
    }

    /// Strokes are opaque within one shared layer, so overlaps never get stronger and the later color wins.
    public static func drawHighlighters(_ annotations: [Annotation], in context: CGContext) {
        guard !annotations.isEmpty else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setAlpha(HighlighterStyle.opacity)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for annotation in annotations {
            guard case .highlighter = annotation.shape, let stroke = annotation.stroke else { continue }
            context.setStrokeColor(annotation.style.color.cgColor)
            context.setLineWidth(annotation.style.thickness)
            context.addPath(stroke.path)
            context.strokePath()
        }
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
