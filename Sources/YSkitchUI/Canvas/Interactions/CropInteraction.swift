import AppKit
import YSkitchCore

/// The whole crop session, from activation to Return or Esc, is one model gesture.
@MainActor
final class CropInteraction: CanvasInteraction {
    static let returnKeyCodes: Set<UInt16> = [36, 76]
    static let escapeKeyCode: UInt16 = 53

    private enum Drag {
        case resize(original: CGRect, handle: BoundsHandle)
        case move(original: CGRect)
        case new
    }

    private let model: DocumentModel
    private let toolbar: ToolbarModel
    private let magnification: () -> CGFloat
    private let overlayDidChange: () -> Void

    /// The session's canvas; the proposed rect stays inside it.
    private var limits: CGRect = .zero
    private var drag: Drag?
    private var start: CGPoint = .zero

    /// Proposed crop in document coordinates; nil outside a session.
    private(set) var rect: CGRect? {
        didSet { if rect != oldValue { overlayDidChange() } }
    }

    init(
        model: DocumentModel, toolbar: ToolbarModel, magnification: @escaping () -> CGFloat,
        overlayDidChange: @escaping () -> Void
    ) {
        self.model = model
        self.toolbar = toolbar
        self.magnification = magnification
        self.overlayDidChange = overlayDidChange
    }

    var isActive: Bool { rect != nil }

    var isDragging: Bool { drag != nil }

    var cursor: NSCursor { .crosshair }

    func activate() {
        guard rect == nil, !model.isInGesture else { return }
        let proposed = model.document.canvasRect
        model.beginGesture()
        model.updateGesture { $0.cropRect = nil }
        limits = model.document.canvasRect
        rect = proposed
    }

    func handleKey(_ event: NSEvent) -> Bool {
        guard isActive else { return false }
        if Self.returnKeyCodes.contains(event.keyCode) {
            apply()
            return true
        }
        if event.keyCode == Self.escapeKeyCode {
            dismiss()
            return true
        }
        return false
    }

    func apply() {
        guard let rect else { return }
        self.rect = nil
        drag = nil
        model.updateGesture { $0.applyCrop(rect) }
        model.endGesture("Crop")
        toolbar.activeTool = toolbar.previousTool
    }

    /// Cancels the session and returns to the previous tool.
    func dismiss() {
        guard isActive else { return }
        cancel()
        toolbar.activeTool = toolbar.previousTool
    }

    func cancel() {
        guard rect != nil else { return }
        rect = nil
        drag = nil
        model.cancelGesture()
    }

    func mouseDown(at point: CGPoint, event: NSEvent) {
        if rect == nil { activate() }
        guard let rect else { return }
        start = clamped(point)
        let radius = (SelectInteraction.handleSize / 2 + SelectInteraction.handleSlop) / magnification()
        if let handle = Self.handle(in: rect, at: point, radius: radius) {
            drag = .resize(original: rect, handle: handle)
        } else if rect.contains(point), rect != limits {
            // A rect filling the whole canvas cannot move, so dragging inside it draws a new one.
            drag = .move(original: rect)
        } else {
            drag = .new
        }
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        guard let drag else { return }
        let point = clamped(point)
        switch drag {
        case .resize(let original, let handle):
            let resized = ResizeMath.bounds(original: original, dragging: handle, to: point).intersection(limits)
            if !resized.isEmpty { rect = resized }
        case .move(let original):
            rect = shiftedInside(original.offsetBy(dx: point.x - start.x, dy: point.y - start.y))
        case .new:
            guard ShapeGeometry.isDrag(from: start, to: point) else { return }
            var new = ShapeGeometry.rect(from: start, to: point, square: false)
            new.size.width = max(new.width, ResizeMath.minimumSize)
            new.size.height = max(new.height, ResizeMath.minimumSize)
            rect = shiftedInside(new)
        }
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        drag = nil
    }

    func flagsChanged(_ event: NSEvent) {}

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, limits.minX), limits.maxX), y: min(max(point.y, limits.minY), limits.maxY))
    }

    private func shiftedInside(_ rect: CGRect) -> CGRect {
        var result = rect
        result.size.width = min(result.width, limits.width)
        result.size.height = min(result.height, limits.height)
        result.origin.x = min(max(result.minX, limits.minX), limits.maxX - result.width)
        result.origin.y = min(max(result.minY, limits.minY), limits.maxY - result.height)
        return result
    }

    /// The handle whose square of half-side `radius` contains `point`, nearest first.
    static func handle(in rect: CGRect, at point: CGPoint, radius: CGFloat) -> BoundsHandle? {
        BoundsHandle.allCases
            .map { ($0, $0.position(in: rect)) }
            .filter { abs($0.1.x - point.x) <= radius && abs($0.1.y - point.y) <= radius }
            .min { hypot($0.1.x - point.x, $0.1.y - point.y) < hypot($1.1.x - point.x, $1.1.y - point.y) }?
            .0
    }
}
