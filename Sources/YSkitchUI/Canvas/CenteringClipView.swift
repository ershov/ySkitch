import AppKit
import YSkitchCore

/// Centers a document smaller than the viewport instead of pinning it to a corner.
final class CenteringClipView: NSClipView {
    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        guard subview === documentView else { return }
        subview.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(documentFrameDidChange),
            name: NSView.frameDidChangeNotification, object: subview)
    }

    override func willRemoveSubview(_ subview: NSView) {
        super.willRemoveSubview(subview)
        NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: subview)
    }

    @objc private func documentFrameDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        scroll(to: constrainBoundsRect(bounds).origin)
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
        // Shadow source only; white here would bleed through the canvas's antialiased edge.
        backgroundColor.setFill()
        documentFrame.fill()
    }

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentFrame = documentView?.frame else { return rect }
        let pixelsPerPoint = ((superview as? NSScrollView)?.magnification ?? 1) * (window?.backingScaleFactor ?? 1)
        if rect.width > documentFrame.width {
            rect.origin.x = PixelAlignment.centeredOrigin(
                documentMin: documentFrame.minX, documentLength: documentFrame.width,
                viewportLength: rect.width, pixelsPerPoint: pixelsPerPoint)
        }
        if rect.height > documentFrame.height {
            rect.origin.y = PixelAlignment.centeredOrigin(
                documentMin: documentFrame.minY, documentLength: documentFrame.height,
                viewportLength: rect.height, pixelsPerPoint: pixelsPerPoint)
        }
        return rect
    }

    /// Routes events on the surround to the canvas so drawing can start outside the image.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let documentView, bounds.contains(convert(point, from: superview)) else { return super.hitTest(point) }
        // The canvas itself, or a subview such as the text editor lying over it.
        return documentView.hitTest(convert(point, from: superview)) ?? documentView
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if let cursor = (documentView as? CanvasView)?.activeCursor { addCursorRect(bounds, cursor: cursor) }
    }
}
