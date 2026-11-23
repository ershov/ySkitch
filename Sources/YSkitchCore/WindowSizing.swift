import CoreGraphics

public enum WindowSizing {
    public static let minimum = CGSize(width: 480, height: 360)

    /// Content size for a document window: document plus chrome, capped to the screen, never below `minimum`.
    public static func contentSize(documentSize: CGSize, chrome: CGSize, visibleFrame: CGSize) -> CGSize {
        CGSize(
            width: max(min(documentSize.width + chrome.width, visibleFrame.width), minimum.width),
            height: max(min(documentSize.height + chrome.height, visibleFrame.height), minimum.height)
        )
    }
}
