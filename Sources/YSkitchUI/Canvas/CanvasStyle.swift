import AppKit

@MainActor
enum CanvasStyle {
    static let surroundColor = NSColor.underPageBackgroundColor

    /// Screen-space values: unaffected by zoom.
    static let shadowOpacity: CGFloat = 0.25
    static let shadowBlur: CGFloat = 6
    static let shadowOffset = NSSize(width: 0, height: -1)
}
