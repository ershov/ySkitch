public enum ToolShortcut {
    public enum Action: Equatable, Sendable {
        case tool(Tool)
        /// Palette index.
        case color(Int)
        case thicknessStep(Int)
        case thicknessFineStep(Int)
    }

    /// The lowercase key that triggers `action`; thickness steps map by sign.
    /// Fine steps map to the shifted characters, as `charactersIgnoringModifiers` reports them.
    public static func key(for action: Action) -> String {
        switch action {
        case .tool(let tool): tool.key.lowercased()
        case .color(let index): "\(index + 1)"
        case .thicknessStep(let steps): steps < 0 ? "[" : "]"
        case .thicknessFineStep(let steps): steps < 0 ? "{" : "}"
        }
    }

    public static func action(for characters: String) -> Action? {
        guard characters.count == 1, let character = characters.first else { return nil }
        switch character {
        case "[": return .thicknessStep(-1)
        case "]": return .thicknessStep(1)
        case "{": return .thicknessFineStep(-1)
        case "}": return .thicknessFineStep(1)
        default: break
        }
        if let digit = character.wholeNumberValue, character.isASCII, (1...Palette.colors.count).contains(digit) {
            return .color(digit - 1)
        }
        let upper = Character(character.uppercased())
        return Tool.allCases.first { $0.key == upper }.map { .tool($0) }
    }
}
