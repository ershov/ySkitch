import AppKit
import YSkitchCore

final class CanvasScrollView: NSScrollView {
    var onMagnificationChange: ((CGFloat) -> Void)?

    private var magnificationObservation: NSKeyValueObservation?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        contentView = CenteringClipView()
        allowsMagnification = true
        minMagnification = Zoom.minimum
        maxMagnification = Zoom.maximum
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = true
        backgroundColor = CanvasStyle.surroundColor
        drawsBackground = true
        magnificationObservation = observe(\.magnification) { scrollView, _ in
            MainActor.assumeIsolated { scrollView.magnificationDidChange() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func magnificationDidChange() {
        documentView?.needsDisplay = true
        onMagnificationChange?(magnification)
    }

    private var visibleCenter: NSPoint {
        let bounds = contentView.bounds
        return NSPoint(x: bounds.midX, y: bounds.midY)
    }

    private var fitMagnification: CGFloat {
        Zoom.fit(content: documentView?.frame.size ?? .zero, viewport: contentView.frame.size)
    }

    override func smartMagnify(with event: NSEvent) {
        let target = abs(magnification - 1) < 0.001 ? fitMagnification : 1
        setMagnification(target, centeredAt: contentView.convert(event.locationInWindow, from: nil))
    }

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else { return super.scrollWheel(with: event) }
        // Line-based wheels report ~1 per notch; treat a line as 10 points.
        let deltaY = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 10
        setMagnification(
            Zoom.wheel(magnification: magnification, deltaY: deltaY),
            centeredAt: contentView.convert(event.locationInWindow, from: nil)
        )
    }

    func zoomIn() {
        setMagnification(Zoom.stepUp(from: magnification), centeredAt: visibleCenter)
    }

    func zoomOut() {
        setMagnification(Zoom.stepDown(from: magnification), centeredAt: visibleCenter)
    }

    func zoomToActualSize() {
        setMagnification(1, centeredAt: visibleCenter)
    }

    func zoomToFit() {
        magnification = fitMagnification
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
