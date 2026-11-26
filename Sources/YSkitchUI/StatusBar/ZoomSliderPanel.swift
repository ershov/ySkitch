import AppKit
import YSkitchCore

/// Borderless pop-up with a vertical logarithmic zoom slider; the knob and value sit over the status-bar label.
@MainActor
final class ZoomSliderPanel: NSPanel {
    static let size = CGSize(width: 100, height: 240)

    var onZoom: ((CGFloat) -> Void)?
    var onDismiss: (() -> Void)?

    private let sliderView: ZoomSliderView
    private var monitor: Any?
    private var resignObserver: NSObjectProtocol?

    var position: Double { sliderView.position }
    var shownMagnification: CGFloat { sliderView.magnification }

    init(magnification: CGFloat) {
        sliderView = ZoomSliderView(frame: CGRect(origin: .zero, size: Self.size), magnification: magnification)
        super.init(
            contentRect: CGRect(origin: .zero, size: Self.size), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        contentView = sliderView
        sliderView.onChange = { [weak self] in self?.apply($0) }
        sliderView.onReset = { [weak self] in self?.apply(1) }
    }

    func setPosition(_ position: Double) { apply(ZoomSlider.magnification(at: position)) }

    func resetToActualSize() { apply(1) }

    private func apply(_ magnification: CGFloat) {
        sliderView.magnification = magnification
        onZoom?(magnification)
    }

    /// Opens over `anchor` (the status-bar label) so the knob row replaces it.
    func present(over anchor: NSView, in parent: NSWindow) {
        let rect = parent.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let origin = ZoomSlider.panelOrigin(
            anchor: CGPoint(x: rect.midX, y: rect.midY), anchorOffset: sliderView.anchorOffset, panelSize: Self.size,
            visibleFrame: (parent.screen ?? NSScreen.main)?.visibleFrame ?? rect)
        setFrameOrigin(origin)
        parent.addChildWindow(self, ordered: .above)
        orderFront(nil)

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self, weak anchor] event in
            guard let self, let anchor else { return event }
            let escape = event.type == .keyDown && event.keyCode == 53
            if escape {
                dismiss()
                return nil
            }
            guard event.type != .keyDown, event.window !== self else { return event }
            dismiss()
            // A press on the anchor only closes, like a pop-up menu, instead of reopening.
            let onAnchor = event.window === anchor.window && anchor.bounds.contains(anchor.convert(event.locationInWindow, from: nil))
            return onAnchor ? nil : event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: parent, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
    }

    /// Follows the mouse until release, as in a pop-up menu: a drag closes the panel on release, a plain click keeps it.
    func track(with event: NSEvent) {
        guard let window = event.window else { return }
        let start = window.convertPoint(toScreen: event.locationInWindow)
        var moved = false
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let point = window.convertPoint(toScreen: next.locationInWindow)
            if abs(point.y - start.y) > 3 || abs(point.x - start.x) > 3 { moved = true }
            if moved { sliderView.drag(toWindowPoint: convertPoint(fromScreen: point)) }
            if next.type == .leftMouseUp {
                if moved { dismiss() }
                return
            }
        }
    }

    func dismiss() {
        guard isVisible else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        monitor = nil
        resignObserver = nil
        parent?.removeChildWindow(self)
        orderOut(nil)
        onDismiss?()
    }
}

@MainActor
private final class ZoomSliderView: NSView {
    private static let trackX: CGFloat = 24
    private static let trackBottom: CGFloat = 20
    private static let trackLength: CGFloat = 200
    private static let valueCenterX: CGFloat = 70
    private static let valueFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    private static let captionFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

    var onChange: ((CGFloat) -> Void)?
    var onReset: (() -> Void)?

    private(set) var position: Double
    var magnification: CGFloat {
        didSet {
            position = ZoomSlider.position(of: magnification)
            needsDisplay = true
        }
    }

    /// Point that lands on the status-bar label's center.
    var anchorOffset: CGPoint { CGPoint(x: Self.valueCenterX, y: knobY) }

    private var knobY: CGFloat { Self.trackBottom + CGFloat(position) * Self.trackLength }

    init(frame: CGRect, magnification: CGFloat) {
        self.magnification = magnification
        position = ZoomSlider.position(of: magnification)
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            onReset?()
        } else {
            drag(toWindowPoint: event.locationInWindow)
        }
    }

    override func mouseDragged(with event: NSEvent) { drag(toWindowPoint: event.locationInWindow) }

    func drag(toWindowPoint point: CGPoint) {
        let y = convert(point, from: nil).y
        onChange?(ZoomSlider.magnification(at: Double((y - Self.trackBottom) / Self.trackLength)))
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        NSColor.windowBackgroundColor.setFill()
        background.fill()
        NSColor.separatorColor.setStroke()
        background.stroke()

        let top = Self.trackBottom + Self.trackLength
        let middle = Self.trackBottom + Self.trackLength / 2
        NSColor.tertiaryLabelColor.setFill()
        CGRect(x: Self.trackX - 1, y: Self.trackBottom, width: 2, height: Self.trackLength).fill()
        CGRect(x: Self.trackX - 6, y: middle - 0.5, width: 12, height: 1).fill()

        for (text, y) in [("500%", top), ("100%", middle), ("20%", Self.trackBottom)] where abs(y - knobY) > 12 {
            draw(text, centeredAt: y, font: Self.captionFont, color: .secondaryLabelColor)
        }
        draw(StatusText.zoom(magnification), centeredAt: knobY, font: Self.valueFont, color: .labelColor)

        let knob = CGRect(x: Self.trackX - 7, y: knobY - 7, width: 14, height: 14)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: knob).fill()
    }

    private func draw(_ text: String, centeredAt y: CGFloat, font: NSFont, color: NSColor) {
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let size = string.size()
        string.draw(at: CGPoint(x: Self.valueCenterX - size.width / 2, y: y - size.height / 2))
    }
}
