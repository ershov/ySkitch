import CoreGraphics

public enum ToolIcon {
    case symbol(String)
    case path(CGPath)
    case text

    public static let stroke: CGFloat = 3.4
    public static let boxSize = CGSize(width: 24, height: 21)

    public static func icon(for tool: Tool) -> ToolIcon {
        switch tool {
        case .select: .symbol("cursorarrow")
        case .text: .text
        case .arrow, .line, .rectangle, .roundedRectangle, .ellipse: .path(centerlinePath(for: tool, in: CGRect(origin: .zero, size: boxSize)))
        case .pen: .symbol("pencil.tip")
        case .highlighter: .symbol("highlighter")
        case .pixelate: .symbol("checkerboard.rectangle")
        case .crop: .symbol("crop")
        }
    }

    /// Stroke join matching the geometry of each code-drawn tool.
    public static func lineJoin(for tool: Tool) -> CGLineJoin {
        tool == .rectangle ? .miter : .round
    }

    /// Centerline of the code-drawn icon; stroked with `stroke` it fits the outer sizes of the design.
    public static func centerlinePath(for tool: Tool, in box: CGRect) -> CGPath {
        let c = CGPoint(x: box.midX, y: box.midY)
        let path = CGMutablePath()
        let inset = stroke / 2
        switch tool {
        case .line, .arrow:
            path.move(to: CGPoint(x: c.x - 8, y: c.y + 8))
            path.addLine(to: CGPoint(x: c.x + 8, y: c.y - 8))
            if tool == .arrow {
                path.move(to: CGPoint(x: c.x - 1, y: c.y - 8))
                path.addLine(to: CGPoint(x: c.x + 8, y: c.y - 8))
                path.addLine(to: CGPoint(x: c.x + 8, y: c.y + 1))
            }
        case .rectangle:
            path.addRect(outerRect(width: 22, height: 16, center: c).insetBy(dx: inset, dy: inset))
        case .roundedRectangle:
            path.addRoundedRect(
                in: outerRect(width: 19, height: 19, center: c).insetBy(dx: inset, dy: inset),
                cornerWidth: 4.5, cornerHeight: 4.5)
        case .ellipse:
            path.addEllipse(in: outerRect(width: 20, height: 20, center: c).insetBy(dx: inset, dy: inset))
        default:
            break
        }
        return path
    }

    private static func outerRect(width: CGFloat, height: CGFloat, center: CGPoint) -> CGRect {
        CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }
}
