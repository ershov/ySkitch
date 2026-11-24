import AppKit

/// Centers a document smaller than the viewport instead of pinning it to a corner.
final class CenteringClipView: NSClipView {
    private var documentFrameObserver: (any NSObjectProtocol)?

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        guard subview === documentView else { return }
        subview.postsFrameChangedNotifications = true
        documentFrameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: subview, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.needsDisplay = true }
        }
    }

    isolated deinit {
        documentFrameObserver.map(NotificationCenter.default.removeObserver)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let documentFrame = documentView?.frame, let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        defer { context.restoreGraphicsState() }
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(CanvasStyle.shadowOpacity)
        shadow.shadowBlurRadius = CanvasStyle.shadowBlur
        shadow.shadowOffset = CanvasStyle.shadowOffset
        shadow.set()
        NSColor.white.setFill()
        documentFrame.fill()
    }

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

    /// Routes events on the surround to the canvas so drawing can start outside the image.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let documentView, bounds.contains(convert(point, from: superview)) else { return super.hitTest(point) }
        return documentView
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if let cursor = (documentView as? CanvasView)?.activeCursor { addCursorRect(bounds, cursor: cursor) }
    }
}
