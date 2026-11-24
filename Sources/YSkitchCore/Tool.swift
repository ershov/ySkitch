import CoreGraphics

public enum Tool: String, CaseIterable, Codable, Sendable {
    case select, text, arrow, line, rectangle, roundedRectangle, ellipse, pen, highlighter, pixelate, crop

    /// Toolbar order: one inner array per visual group.
    public static let groups: [[Tool]] = [
        [.select],
        [.text],
        [.arrow, .line, .rectangle, .roundedRectangle, .ellipse],
        [.pen, .highlighter],
        [.pixelate],
        [.crop],
    ]

    public var key: Character {
        switch self {
        case .select: "V"
        case .text: "T"
        case .arrow: "A"
        case .line: "L"
        case .rectangle: "R"
        case .roundedRectangle: "U"
        case .ellipse: "O"
        case .pen: "P"
        case .highlighter: "H"
        case .pixelate: "X"
        case .crop: "C"
        }
    }

    public var name: String {
        switch self {
        case .select: "Select"
        case .text: "Text"
        case .arrow: "Arrow"
        case .line: "Line"
        case .rectangle: "Rectangle"
        case .roundedRectangle: "Rounded Rectangle"
        case .ellipse: "Ellipse"
        case .pen: "Pen"
        case .highlighter: "Highlighter"
        case .pixelate: "Pixelate"
        case .crop: "Crop"
        }
    }

    public var usesColor: Bool {
        switch self {
        case .select, .pixelate, .crop: false
        default: true
        }
    }

    public static let strokeRange: ClosedRange<CGFloat> = 1...40
    public static let strokeDefault: CGFloat = 4
    public static let highlighterRange: ClosedRange<CGFloat> = 4...60
    public static let highlighterDefault: CGFloat = 20
    public static let fontSizeRange: ClosedRange<CGFloat> = 10...120
    public static let fontSizeDefault: CGFloat = 24
    public static let pixelateRange: ClosedRange<CGFloat> = 2...40
    public static let pixelateDefault: CGFloat = 10

    /// Stroke width, font size (text) or block size (pixelate); nil when the tool has no size.
    public var thicknessRange: ClosedRange<CGFloat>? {
        switch self {
        case .arrow, .line, .rectangle, .roundedRectangle, .ellipse, .pen: Self.strokeRange
        case .highlighter: Self.highlighterRange
        case .text: Self.fontSizeRange
        case .pixelate: Self.pixelateRange
        case .select, .crop: nil
        }
    }

    /// What `thicknessRange` measures; nil when the tool has no size.
    public var thicknessName: String? {
        switch self {
        case .arrow, .line, .rectangle, .roundedRectangle, .ellipse, .pen, .highlighter: "Width"
        case .text: "Font size"
        case .pixelate: "Block size"
        case .select, .crop: nil
        }
    }

    public var defaultThickness: CGFloat? {
        switch self {
        case .arrow, .line, .rectangle, .roundedRectangle, .ellipse, .pen: Self.strokeDefault
        case .highlighter: Self.highlighterDefault
        case .text: Self.fontSizeDefault
        case .pixelate: Self.pixelateDefault
        case .select, .crop: nil
        }
    }
}
