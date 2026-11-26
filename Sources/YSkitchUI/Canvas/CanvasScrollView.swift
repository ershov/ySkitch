import AppKit
import YSkitchCore

final class CanvasScrollView: NSScrollView {
    var onMagnificationChange: ((CGFloat) -> Void)?
    var onFitModeChange: ((Bool) -> Void)?
    var onDrop: ((NSPasteboard) -> Bool)?

    /// While on, the view keeps fitting the canvas; any user zoom turns it off.
    private(set) var isFitMode = false {
        didSet { if isFitMode != oldValue { onFitModeChange?(isFitMode) } }
    }

    private var magnificationObservation: NSKeyValueObservation?
    private var isFitting = false
    private var fitted: (content: NSSize, viewport: NSSize)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        contentView = CenteringClipView()
        allowsMagnification = true
        minMagnification = Zoom.minimum
        maxMagnification = Zoom.maximum
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = true
        usesPredominantAxisScrolling = false
        backgroundColor = CanvasStyle.surroundColor
        drawsBackground = true
        registerForDraggedTypes([.fileURL, .png, .tiff])
        magnificationObservation = observe(\.magnification) { scrollView, _ in
            MainActor.assumeIsolated { scrollView.magnificationDidChange() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        PasteboardImageReader.containsImage(sender.draggingPasteboard) ? .copy : []
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        onDrop?(sender.draggingPasteboard) ?? false
    }

    private func magnificationDidChange() {
        documentView?.needsDisplay = true
        onMagnificationChange?(magnification)
    }

    private var visibleCenter: NSPoint {
        let bounds = contentView.bounds
        return NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private var fitViewportSize: NSSize {
        NSScrollView.contentSize(
            forFrameSize: frame.size,
            horizontalScrollerClass: nil,
            verticalScrollerClass: nil,
            borderType: borderType,
            controlSize: .regular,
            scrollerStyle: scrollerStyle
        )
    }

    private var fitMagnification: CGFloat {
        let viewport = fitViewportSize
        return Zoom.fit(
            content: documentView?.frame.size ?? .zero, viewport: viewport, margin: Zoom.fitMargin(viewport: viewport))
    }

    override func tile() {
        super.tile()
        if isFitMode, !isFitting, fitted?.viewport != fitViewportSize { fit() }
    }

    override func magnify(with event: NSEvent) {
        isFitMode = false
        super.magnify(with: event)
    }

    override func smartMagnify(with event: NSEvent) {
        toggleSmartZoom(at: contentView.convert(event.locationInWindow, from: nil))
    }

    func toggleSmartZoom(at point: NSPoint) {
        if abs(magnification - 1) < 0.001 {
            setFitMode(true)
        } else {
            isFitMode = false
            setMagnification(1, centeredAt: point)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else { return super.scrollWheel(with: event) }
        isFitMode = false
        // Line-based wheels report ~1 per notch; treat a line as 10 points.
        let deltaY = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 10
        setMagnification(
            Zoom.wheel(
                magnification: magnification, deltaY: deltaY,
                invertedFromDevice: event.isDirectionInvertedFromDevice
            ),
            centeredAt: contentView.convert(event.locationInWindow, from: nil)
        )
    }

    func zoomIn() {
        isFitMode = false
        setMagnification(Zoom.stepUp(from: magnification), centeredAt: visibleCenter)
    }

    func zoomOut() {
        isFitMode = false
        setMagnification(Zoom.stepDown(from: magnification), centeredAt: visibleCenter)
    }

    func zoom(to magnification: CGFloat) {
        isFitMode = false
        setMagnification(magnification, centeredAt: visibleCenter)
    }

    func zoomToActualSize() {
        isFitMode = false
        setMagnification(1, centeredAt: visibleCenter)
    }

    /// Turning it on fits immediately; turning it off keeps the current zoom.
    func setFitMode(_ on: Bool) {
        isFitMode = on
        if on { fit() }
    }

    /// Re-fits after a viewport or canvas size change.
    func refitIfNeeded() {
        guard isFitMode, !isFitting,
            fitted?.content != documentView?.frame.size || fitted?.viewport != fitViewportSize
        else { return }
        fit()
    }

    private func fit() {
        guard !isFitting else { return }
        isFitting = true
        defer { isFitting = false }
        magnification = fitMagnification
        tile()
        fitted = (documentView?.frame.size ?? .zero, fitViewportSize)
        guard let documentFrame = documentView?.frame else { return }
        var bounds = contentView.bounds
        bounds.origin = NSPoint(
            x: documentFrame.midX - bounds.width / 2,
            y: documentFrame.midY - bounds.height / 2
        )
        contentView.scroll(to: contentView.constrainBoundsRect(bounds).origin)
        reflectScrolledClipView(contentView)
    }
}
