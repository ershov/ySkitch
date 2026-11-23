import AppKit
import Observation
import YSkitchCore

/// Document view of `CanvasScrollView`; one unit is one document point.
final class CanvasView: NSView {
    let model: DocumentModel
    let toolbar: ToolbarModel
    let selection: SelectionModel

    private var isPanMode = false
    private var panLastLocation: NSPoint?
    private var previousAcceptsMouseMoved = false
    private var interaction: (tool: Tool, handler: any CanvasInteraction)?
    private var canvasOrigin: CGPoint
    private(set) lazy var textEditor = TextEditingController(canvas: self, model: model, toolbar: toolbar)

    init(model: DocumentModel, toolbar: ToolbarModel, selection: SelectionModel) {
        self.model = model
        self.toolbar = toolbar
        self.selection = selection
        canvasOrigin = model.document.canvasRect.origin
        super.init(frame: NSRect(origin: .zero, size: model.document.canvasRect.size))
        clipsToBounds = true
        observeActiveTool()
        toolbar.onActiveToolChange = { [weak self] in self?.textEditor.commit() }
    }

    private func observeActiveTool() {
        withObservationTracking {
            _ = self.toolbar.activeTool
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.invalidateCursors()
                self.observeActiveTool()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// Starts in-place editing of a text annotation, caret at the end.
    func beginTextEditing(annotationID: UUID) {
        textEditor.beginEditing(annotationID: annotationID)
    }

    func commitTextEditing() {
        textEditor.commit()
    }

    func documentDidChange() {
        let canvas = model.document.canvasRect
        let shift = CGPoint(x: canvasOrigin.x - canvas.minX, y: canvasOrigin.y - canvas.minY)
        canvasOrigin = canvas.origin
        setFrameSize(canvas.size)
        if shift != .zero {
            keepContentInPlace(shift: shift)
            textEditor.canvasOriginDidChange()
        }
        textEditor.documentDidChange()
        needsDisplay = true
    }

    /// Scrolls by `shift` so content stays put on screen when the canvas origin moves.
    private func keepContentInPlace(shift: CGPoint) {
        guard let scrollView = enclosingScrollView else { return }
        let clipView = scrollView.contentView
        var bounds = clipView.bounds
        bounds.origin.x += shift.x
        bounds.origin.y += shift.y
        clipView.scroll(to: clipView.constrainBoundsRect(bounds).origin)
        scrollView.reflectScrolledClipView(clipView)
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
        drawSelectionOverlay(in: context)
    }

    private func drawSelectionOverlay(in context: CGContext) {
        let selected = selection.selectedAnnotations
        let marquee = (interaction?.handler as? SelectInteraction)?.marquee
        guard !selected.isEmpty || marquee != nil else { return }
        let pixel = 1 / (enclosingScrollView?.magnification ?? 1)
        let accent = NSColor.controlAccentColor.cgColor
        context.saveGState()
        defer { context.restoreGState() }
        context.setLineWidth(pixel)
        context.setStrokeColor(accent)
        for annotation in selected {
            context.stroke(annotation.bounds.insetBy(dx: -pixel / 2, dy: -pixel / 2))
        }
        if selected.count == 1, let annotation = selected.first {
            let side = SelectInteraction.handleSize * pixel
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            for handle in Handles.handles(for: annotation) {
                let rect = CGRect(
                    x: handle.position.x - side / 2, y: handle.position.y - side / 2, width: side, height: side)
                context.fill(rect)
                context.stroke(rect.insetBy(dx: pixel / 2, dy: pixel / 2))
            }
        }
        if let marquee {
            context.setFillColor(accent.copy(alpha: 0.15) ?? accent)
            context.fill(marquee)
            context.stroke(marquee.insetBy(dx: pixel / 2, dy: pixel / 2))
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            if let select = currentInteraction as? SelectInteraction, !select.isDragging {
                selection.clear()
            } else {
                currentInteraction?.cancel()
            }
            return
        }
        if Self.deleteKeyCodes.contains(event.keyCode), !selection.isEmpty, !model.isInGesture,
           event.modifierFlags.isDisjoint(with: [.command, .control, .option]) {
            selection.deleteSelected()
            return
        }
        if event.keyCode == Self.spaceKeyCode {
            if !event.isARepeat, event.modifierFlags.isDisjoint(with: [.command, .control, .option]) {
                beginPanMode()
            }
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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        guard let window else { return }
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        endPanMode()
    }

    override func mouseDown(with event: NSEvent) {
        if isPanMode { return }
        if textEditor.isEditing { return textEditor.commit() }
        currentInteraction?.mouseDown(at: documentPoint(event), event: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isPanMode else { return currentInteraction?.mouseDragged(to: documentPoint(event), event: event) ?? () }
        panDrag(to: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        guard isPanMode else { return super.mouseMoved(with: event) }
        panDrag(to: event.locationInWindow)
    }

    override func mouseUp(with event: NSEvent) {
        if isPanMode { return }
        currentInteraction?.mouseUp(at: documentPoint(event), event: event)
    }

    override func flagsChanged(with event: NSEvent) {
        guard !isPanMode, let interaction = currentInteraction else { return super.flagsChanged(with: event) }
        interaction.flagsChanged(event)
    }

    override func resetCursorRects() {
        if let cursor = activeCursor { addCursorRect(bounds, cursor: cursor) }
    }

    var activeCursor: NSCursor? { panCursor ?? currentInteraction?.cursor }

    private func invalidateCursors() {
        window?.invalidateCursorRects(for: self)
        if let clip = superview { window?.invalidateCursorRects(for: clip) }
    }

    private func documentPoint(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        let origin = model.document.canvasRect.origin
        return CGPoint(x: point.x + origin.x, y: point.y + origin.y)
    }

    private var currentInteraction: (any CanvasInteraction)? {
        let tool = toolbar.activeTool
        if let interaction, interaction.tool == tool { return interaction.handler }
        interaction?.handler.cancel()
        interaction = nil
        let handler: (any CanvasInteraction)? = switch tool {
        case .rectangle, .roundedRectangle, .ellipse, .pixelate:
            ShapeDrawingInteraction(tool: tool, model: model, toolbar: toolbar)
        case .line, .arrow:
            LineDrawingInteraction(tool: tool, model: model, toolbar: toolbar)
        case .select:
            SelectInteraction(
                model: model, selection: selection,
                magnification: { [weak self] in self?.enclosingScrollView?.magnification ?? 1 },
                beginTextEditing: { [weak self] in self?.beginTextEditing(annotationID: $0) },
                overlayDidChange: { [weak self] in self?.needsDisplay = true })
        case .text:
            TextInteraction(model: model, editor: textEditor)
        case .pen, .highlighter:
            FreehandDrawingInteraction(
                tool: tool, model: model, toolbar: toolbar,
                magnification: { [weak self] in self?.enclosingScrollView?.magnification ?? 1 })
        default: nil
        }
        interaction = handler.map { (tool, $0) }
        return handler
    }

    // MARK: - Space panning

    private static let spaceKeyCode: UInt16 = 49
    private static let escapeKeyCode: UInt16 = 53
    private static let deleteKeyCodes: Set<UInt16> = [51, 117]

    private var panCursor: NSCursor? { isPanMode ? .closedHand : nil }

    private func beginPanMode() {
        guard !isPanMode, !model.isInGesture else { return }
        isPanMode = true
        panLastLocation = window?.mouseLocationOutsideOfEventStream
        previousAcceptsMouseMoved = window?.acceptsMouseMovedEvents ?? false
        window?.acceptsMouseMovedEvents = true
        updatePanCursor()
    }

    private func endPanMode() {
        guard isPanMode else { return }
        isPanMode = false
        panLastLocation = nil
        window?.acceptsMouseMovedEvents = previousAcceptsMouseMoved
        updatePanCursor()
    }

    private func updatePanCursor() {
        invalidateCursors()
        (panCursor ?? currentInteraction?.cursor ?? .arrow).set()
    }

    /// `location` is in window coordinates (y up); the clip view is flipped like this view.
    private func panDrag(to location: NSPoint) {
        NSCursor.closedHand.set()
        guard let last = panLastLocation else { panLastLocation = location; return }
        guard let clipView = enclosingScrollView?.contentView else { return }
        panLastLocation = location
        let magnification = enclosingScrollView?.magnification ?? 1
        var bounds = clipView.bounds
        bounds.origin.x -= (location.x - last.x) / magnification
        bounds.origin.y += (location.y - last.y) / magnification
        clipView.scroll(to: clipView.constrainBoundsRect(bounds).origin)
        enclosingScrollView?.reflectScrolledClipView(clipView)
    }
}
