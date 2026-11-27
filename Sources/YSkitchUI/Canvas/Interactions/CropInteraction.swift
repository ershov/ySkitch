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

    /// The canvas before the session, i.e. the current image; a double-click proposes it.
    private var initialRect: CGRect = .zero
    private var drag: Drag?
    private var start: CGPoint = .zero
    private var last: CGPoint = .zero

    /// Proposed crop in document coordinates; nil outside a session. May extend beyond the canvas,
    /// which then grows to show it.
    private(set) var rect: CGRect? {
        didSet {
            guard rect != oldValue else { return }
            if let rect, model.isInGesture { model.updateGesture { $0.extendCanvas(toInclude: rect) } }
            overlayDidChange()
        }
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

    /// Top-left of the canvas before the session; nil outside a session.
    var currentImageOrigin: CGPoint? { rect == nil ? nil : initialRect.origin }

    var isDragging: Bool { drag != nil }

    var statusGeometry: StatusGeometry? {
        rect.map { .box(rect: $0, name: Tool.crop.name, thickness: nil) }
    }

    var cursor: NSCursor { .crosshair }

    func activate() {
        guard rect == nil, !model.isInGesture else { return }
        initialRect = model.document.canvasRect
        model.beginGesture()
        model.updateGesture { $0.cropRect = nil }
        rect = initialRect
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
        start = point
        last = point
        if event.clickCount == 2 {
            drag = nil
            self.rect = initialRect
            return
        }
        let radius = (SelectInteraction.handleSize / 2 + SelectInteraction.handleSlop) / magnification()
        if let handle = Self.handle(in: rect, at: point, radius: radius) {
            drag = .resize(original: rect, handle: handle)
        } else if rect.contains(point), rect != model.document.canvasRect {
            // Dragging inside a rect that fills the whole canvas draws a new one.
            drag = .move(original: rect)
        } else {
            drag = .new
        }
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        last = point
        update(flags: event.modifierFlags)
    }

    private func update(flags: NSEvent.ModifierFlags) {
        guard let drag else { return }
        let point = last
        switch drag {
        case .resize(let original, let handle):
            rect = ResizeMath.bounds(
                original: original, dragging: handle, to: point,
                centered: flags.contains(.option), proportional: flags.contains(.shift))
        case .move(let original):
            rect = original.offsetBy(dx: point.x - start.x, dy: point.y - start.y)
        case .new:
            guard ShapeGeometry.isDrag(from: start, to: point) else { return }
            var new = ShapeGeometry.rect(from: start, to: point, square: false, centered: flags.contains(.option))
            new.size.width = max(new.width, ResizeMath.minimumSize)
            new.size.height = max(new.height, ResizeMath.minimumSize)
            rect = new
        }
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        drag = nil
    }

    func flagsChanged(_ event: NSEvent) { update(flags: event.modifierFlags) }

    /// The handle whose square of half-side `radius` contains `point`, nearest first.
    static func handle(in rect: CGRect, at point: CGPoint, radius: CGFloat) -> BoundsHandle? {
        // Swift 6.1 times out when type-checking these operations as one expression.
        let handles = BoundsHandle.allCases.map { (handle: $0, position: $0.position(in: rect)) }
        let hits = handles.filter {
            abs($0.position.x - point.x) <= radius && abs($0.position.y - point.y) <= radius
        }
        let nearest = hits.min { lhs, rhs in
            let leftDistance = hypot(lhs.position.x - point.x, lhs.position.y - point.y)
            let rightDistance = hypot(rhs.position.x - point.x, rhs.position.y - point.y)
            return leftDistance < rightDistance
        }
        return nearest?.handle
    }
}
