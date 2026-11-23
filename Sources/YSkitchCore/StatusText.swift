import CoreGraphics
import Foundation

public enum StatusText {
    public static func size(canvas: CGSize, scale: CGFloat) -> String {
        let pixels = "\(Int(ceil(canvas.width * scale)))×\(Int(ceil(canvas.height * scale)))"
        let points = "\(Int(canvas.width.rounded()))×\(Int(canvas.height.rounded()))"
        let scaleText = scale == scale.rounded() ? "\(Int(scale))" : String(format: "%.1f", Double(scale))
        return "\(pixels) px · \(points) pt · @\(scaleText)x"
    }

    public static func zoom(_ magnification: CGFloat) -> String {
        "\(Int((magnification * 100).rounded()))%"
    }
}
