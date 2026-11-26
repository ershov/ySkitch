import CoreGraphics

public enum OutlineStyle {
    /// Text is always outlined; every other outlinable tool only when this is on.
    public static let outlinesShapes = false

    /// Points.
    public static let haloBlur: CGFloat = 2
    public static let haloColor = CGColor(gray: 0, alpha: 0.5)
    public static let whiteRatio: CGFloat = 0.25
    /// Points.
    public static let whiteMinimum: CGFloat = 1

    public static func whiteWidth(forLineWidth lineWidth: CGFloat) -> CGFloat {
        max(whiteMinimum, lineWidth * whiteRatio)
    }

    /// How far the rendering reaches beyond the shape's own edge.
    public static func extent(outlineWidth: CGFloat) -> CGFloat {
        outlineWidth + haloBlur * 2
    }
}

public enum OutlinedDrawing {
    public static func stroke(
        _ path: CGPath, lineWidth: CGFloat, color: CGColor,
        lineCap: CGLineCap, lineJoin: CGLineJoin, in context: CGContext
    ) {
        let white = OutlineStyle.whiteWidth(forLineWidth: lineWidth)
        drawOutline(in: context) {
            context.setStrokeColor(CGColor(gray: 1, alpha: 1))
            context.setLineWidth(lineWidth + 2 * white)
            context.setLineCap(lineCap)
            context.setLineJoin(lineJoin)
            context.addPath(path)
            context.strokePath()
        }

        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        context.setLineCap(lineCap)
        context.setLineJoin(lineJoin)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    public static func fill(_ path: CGPath, color: CGColor, outlineWidth: CGFloat, in context: CGContext) {
        drawOutline(in: context) {
            let whiteColor = CGColor(gray: 1, alpha: 1)
            context.setFillColor(whiteColor)
            context.setStrokeColor(whiteColor)
            context.setLineWidth(2 * outlineWidth)
            context.setLineJoin(.round)
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        }

        context.saveGState()
        context.setFillColor(color)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    private static func drawOutline(in context: CGContext, _ body: () -> Void) {
        let ctm = context.userSpaceToDeviceSpaceTransform
        let deviceScale = hypot(ctm.a, ctm.b)
        context.saveGState()
        context.setShadow(
            offset: .zero, blur: OutlineStyle.haloBlur * deviceScale, color: OutlineStyle.haloColor)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        body()
        context.endTransparencyLayer()
        context.restoreGState()
    }
}
