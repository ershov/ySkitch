import AppKit

/// Centers a document smaller than the viewport instead of pinning it to a corner.
final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentFrame = documentView?.frame else { return rect }
        if rect.width > documentFrame.width {
            rect.origin.x = documentFrame.minX - (rect.width - documentFrame.width) / 2
        }
        if rect.height > documentFrame.height {
            rect.origin.y = documentFrame.minY - (rect.height - documentFrame.height) / 2
        }
        return rect
    }
}
