import CoreGraphics
import Foundation

public enum StatusText {
    public static func size(canvas: CGSize, scale: CGFloat) -> String {
        let (pixelWidth, pixelHeight) = Document.pixelSize(points: canvas, scale: scale)
        let pixels = "\(pixelWidth)×\(pixelHeight)"
        let points = "\(Int(canvas.width.rounded()))×\(Int(canvas.height.rounded()))"
        let scaleText = scale == scale.rounded() ? "\(Int(scale))" : String(format: "%.1f", Double(scale))
        return "\(pixels) px · \(points) pt · @\(scaleText)x"
    }

    public static func zoom(_ magnification: CGFloat) -> String {
        "\(Int((magnification * 100).rounded()))%"
    }

    /// Coordinates are image pixels relative to `canvasOrigin`, y down.
    public static func geometry(_ geometry: StatusGeometry, canvasOrigin: CGPoint, scale: CGFloat) -> String {
        func pixel(_ p: CGPoint) -> (x: Int, y: Int) {
            (Int(((p.x - canvasOrigin.x) * scale).rounded()), Int(((p.y - canvasOrigin.y) * scale).rounded()))
        }
        func span(_ from: CGPoint, _ to: CGPoint) -> String {
            let (a, b) = (pixel(from), pixel(to))
            return "(\(a.x), \(a.y)) → (\(b.x), \(b.y))"
        }
        switch geometry {
        case .segment(let name, let from, let to, let thickness):
            let dx = (to.x - from.x) * scale
            let dy = (to.y - from.y) * scale
            let length = Int(hypot(dx, dy).rounded())
            // Counter-clockwise on screen; document y points down.
            var angle = Int((atan2(-dy, dx) * 180 / .pi).rounded())
            if angle == -180 { angle = 180 }
            return [name, span(from, to), "\(length) px", "\(angle)°", points(thickness)].joined(separator: " · ")
        case .box(let name, let from, let to, let thickness):
            let (a, b) = (pixel(from), pixel(to))
            var fields = [name, span(from, to), "\(abs(b.x - a.x))×\(abs(b.y - a.y)) px"]
            if let thickness { fields.append(points(thickness)) }
            return fields.joined(separator: " · ")
        }
    }

    /// Nil for tools without a size.
    public static func thickness(tool: Tool, value: CGFloat) -> String? {
        tool.thicknessName.map { "\(tool.name) · \($0) \(points(value))" }
    }

    private static func points(_ value: CGFloat) -> String {
        let text = value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", Double(value))
        return "\(text) pt"
    }
}
