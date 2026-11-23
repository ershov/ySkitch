import AppKit
import YSkitchCore

/// Document view of `CanvasScrollView`; one unit is one document point.
final class CanvasView: NSView {
    let model: DocumentModel
    let toolbar: ToolbarModel

    private var isPanMode = false
    private var panLastLocation: NSPoint?

    init(model: DocumentModel, toolbar: ToolbarModel) {
        self.model = model
        self.toolbar = toolbar
        super.init(frame: NSRect(origin: .zero, size: model.document.canvasRect.size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    func documentDidChange() {
        setFrameSize(model.document.canvasRect.size)
        needsDisplay = true
    }

    /// Crisp pixels once an image pixel covers at least 2×2 device pixels.
    static func interpolation(
        magnification: CGFloat, backingScale: CGFloat, documentScale: CGFloat
    ) -> CGInterpolationQuality {
        magnification * backingScale / documentScale >= 2 ? .none : .high
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = Self.interpolation(
            magnification: enclosingScrollView?.magnification ?? 1,
            backingScale: window?.backingScaleFactor ?? 1,
            documentScale: model.document.scale
        )
        let origin = model.document.canvasRect.origin
        context.translateBy(x: -origin.x, y: -origin.y)
        Renderer.draw(model.document, in: context)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == Self.spaceKeyCode {
            if !event.isARepeat { beginPanMode() }
            return
        }
        if event.modifierFlags.isDisjoint(with: [.command, .control, .option]),
           let action = event.charactersIgnoringModifiers.flatMap(ToolShortcut.action(for:)) {
            toolbar.perform(action)
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        guard event.keyCode == Self.spaceKeyCode else { return super.keyUp(with: event) }
        endPanMode()
    }

    override func resignFirstResponder() -> Bool {
        endPanMode()
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        guard isPanMode else { return super.mouseDown(with: event) }
        panLastLocation = event.locationInWindow
        updatePanCursor()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isPanMode else { return super.mouseDragged(with: event) }
        panDrag(to: event.locationInWindow)
    }

    override func mouseUp(with event: NSEvent) {
        guard isPanMode else { return super.mouseUp(with: event) }
        panLastLocation = nil
        updatePanCursor()
    }

    override func resetCursorRects() {
        if let cursor = panCursor { addCursorRect(bounds, cursor: cursor) }
    }

    // MARK: - Space+drag panning

    private static let spaceKeyCode: UInt16 = 49

    private var panCursor: NSCursor? {
        guard isPanMode else { return nil }
        return panLastLocation == nil ? .openHand : .closedHand
    }

    private func beginPanMode() {
        guard !isPanMode else { return }
        isPanMode = true
        updatePanCursor()
    }

    private func endPanMode() {
        guard isPanMode else { return }
        isPanMode = false
        panLastLocation = nil
        updatePanCursor()
    }

    private func updatePanCursor() {
        window?.invalidateCursorRects(for: self)
        (panCursor ?? .arrow).set()
    }

    /// `location` is in window coordinates (y up); the clip view is flipped like this view.
    private func panDrag(to location: NSPoint) {
        guard let last = panLastLocation, let clipView = enclosingScrollView?.contentView else { return }
        panLastLocation = location
        let magnification = enclosingScrollView?.magnification ?? 1
        var bounds = clipView.bounds
        bounds.origin.x -= (location.x - last.x) / magnification
        bounds.origin.y += (location.y - last.y) / magnification
        clipView.scroll(to: clipView.constrainBoundsRect(bounds).origin)
        enclosingScrollView?.reflectScrolledClipView(clipView)
    }
}
