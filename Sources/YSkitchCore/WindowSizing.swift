import CoreGraphics

public enum WindowSizing {
    /// Empty space kept around the document on each side, in points.
    public static let margin: CGFloat = 60

    /// Content size for a document window: document plus margin and chrome, capped to the screen, never below `minimum`.
    public static func contentSize(documentSize: CGSize, chrome: CGSize, visibleFrame: CGSize, minimum: CGSize) -> CGSize {
        CGSize(
            width: max(min(documentSize.width + 2 * margin + chrome.width, visibleFrame.width), minimum.width),
            height: max(min(documentSize.height + 2 * margin + chrome.height, visibleFrame.height), minimum.height)
        )
    }
}
