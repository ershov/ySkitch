import CoreGraphics
import CoreText

public struct TextContent: Codable, Equatable, Sendable {
    /// Top-left corner of the first line.
    public var origin: CGPoint
    public var string: String

    public init(origin: CGPoint, string: String) {
        self.origin = origin
        self.string = string
    }
}

public enum TextStyle {
    public static let outlineRatio: CGFloat = 0.1
    /// Points.
    public static let outlineMinimum: CGFloat = 1.5

    public static func font(size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }

    public static func ascent(fontSize: CGFloat) -> CGFloat {
        CTFontGetAscent(font(size: fontSize))
    }

    public static func lineHeight(fontSize: CGFloat) -> CGFloat {
        lineHeight(font(size: fontSize))
    }

    public static func outlineWidth(fontSize: CGFloat) -> CGFloat {
        max(outlineMinimum, fontSize * outlineRatio)
    }

    static func lineHeight(_ font: CTFont) -> CGFloat {
        CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }
}
