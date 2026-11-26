import AppKit
import YSkitchCore

@MainActor
final class ShapeDrawingInteraction: CanvasInteraction {
    private let model: DocumentModel
    private let toolbar: ToolbarModel
    private let tool: Tool
    private let clickSelector: ClickSelector

    private var start: CGPoint?
    private var last: CGPoint = .zero
    private var annotationID: UUID?
    private var rect: CGRect = .zero
    private var thickness: CGFloat = 0

    init(tool: Tool, model: DocumentModel, toolbar: ToolbarModel, clickSelector: ClickSelector) {
        self.tool = tool
        self.model = model
        self.toolbar = toolbar
        self.clickSelector = clickSelector
    }

    var cursor: NSCursor { .crosshair }

    func mouseDown(at point: CGPoint, event: NSEvent) {
        cancel()
        let style = toolbar.currentStyle
        let annotation = Annotation(
            style: AnnotationStyle(color: style.color, thickness: style.thickness),
            shape: shape(for: CGRect(origin: point, size: .zero))
        )
        start = point
        last = point
        rect = CGRect(origin: point, size: .zero)
        thickness = style.thickness
        annotationID = annotation.id
        model.beginGesture()
        model.updateGesture { $0.annotations.append(annotation) }
    }

    func mouseDragged(to point: CGPoint, event: NSEvent) {
        last = point
        update(flags: event.modifierFlags)
    }

    func mouseUp(at point: CGPoint, event: NSEvent) {
        guard let start else { return }
        self.start = nil
        annotationID = nil
        if ShapeGeometry.isDrag(from: start, to: point) {
            model.endGesture(actionName)
            clickSelector.selection.clear()
        } else {
            model.cancelGesture()
            clickSelector.click(at: start)
        }
    }

    func flagsChanged(_ event: NSEvent) {
        guard start != nil else { return }
        update(flags: event.modifierFlags)
    }

    /// The rect's corner opposite the cursor to the cursor's corner.
    var statusGeometry: StatusGeometry? {
        guard let start else { return nil }
        let towardMin = (x: last.x < start.x, y: last.y < start.y)
        let cursorCorner = CGPoint(x: towardMin.x ? rect.minX : rect.maxX, y: towardMin.y ? rect.minY : rect.maxY)
        let oppositeCorner = CGPoint(x: towardMin.x ? rect.maxX : rect.minX, y: towardMin.y ? rect.maxY : rect.minY)
        return .box(name: tool.name, from: oppositeCorner, to: cursorCorner, thickness: thickness)
    }

    func cancel() {
        guard start != nil else { return }
        start = nil
        annotationID = nil
        model.cancelGesture()
    }

    private func update(flags: NSEvent.ModifierFlags) {
        guard let start, let id = annotationID else { return }
        rect = ShapeGeometry.rect(
            from: start, to: last, square: flags.contains(.shift), centered: flags.contains(.option))
        let shape = shape(for: rect)
        model.updateGesture { document in
            guard let index = document.annotations.firstIndex(where: { $0.id == id }) else { return }
            document.annotations[index].shape = shape
        }
    }

    private func shape(for rect: CGRect) -> AnnotationShape {
        switch tool {
        case .roundedRectangle: .roundedRectangle(rect)
        case .ellipse: .ellipse(rect)
        case .pixelate: .pixelate(rect)
        default: .rectangle(rect)
        }
    }

    private var actionName: String {
        switch tool {
        case .roundedRectangle: "Draw Rounded Rectangle"
        case .ellipse: "Draw Ellipse"
        case .pixelate: "Pixelate"
        default: "Draw Rectangle"
        }
    }
}
