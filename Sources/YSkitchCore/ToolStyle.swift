import CoreGraphics

public struct ToolStyle: Codable, Equatable, Sendable {
    public var color: RGBAColor
    public var thickness: CGFloat

    public init(color: RGBAColor, thickness: CGFloat) {
        self.color = color
        self.thickness = thickness
    }

    public static func defaultStyle(for tool: Tool) -> ToolStyle {
        ToolStyle(color: Palette.defaultColor, thickness: tool.defaultThickness ?? 1)
    }
}

/// Per-tool styles; unset tools fall back to `ToolStyle.defaultStyle(for:)`.
public struct ToolStyles: Codable, Equatable, Sendable {
    private var storage: [Tool: ToolStyle]

    public init(_ styles: [Tool: ToolStyle] = [:]) {
        storage = styles
    }

    public subscript(tool: Tool) -> ToolStyle {
        get { storage[tool] ?? .defaultStyle(for: tool) }
        set { storage[tool] = newValue }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: ToolStyle].self)
        storage = Dictionary(uniqueKeysWithValues: raw.compactMap { key, style in
            Tool(rawValue: key).map { ($0, style) }
        })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Dictionary(uniqueKeysWithValues: storage.map { ($0.key.rawValue, $0.value) }))
    }
}
