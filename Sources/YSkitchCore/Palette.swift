public enum Palette {
    /// Index `i` is selected by key `i + 1`.
    public static let colors: [RGBAColor] = [
        RGBAColor(hex: 0xFF2500),
        RGBAColor(hex: 0xFF941A),
        RGBAColor(hex: 0xFEF500),
        RGBAColor(hex: 0x00E700),
        RGBAColor(hex: 0x198EFE),
        RGBAColor(hex: 0xFF2E6C),
        RGBAColor(hex: 0xFFFFFF),
        RGBAColor(hex: 0x000000),
    ]

    public static let defaultColorIndex = 5
    public static let defaultColor = colors[defaultColorIndex]
}
