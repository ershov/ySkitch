import AppKit
import Observation
import YSkitchCore

/// Edits a text annotation in place. The model renders the text live; the overlay text view only
/// supplies caret, selection and input, with its own glyphs drawn transparent.
@MainActor
final class TextEditingController: NSObject, NSTextViewDelegate {
    private unowned let canvas: CanvasView
    private let model: DocumentModel
    private let toolbar: ToolbarModel

    private struct Session {
        let annotationID: UUID
        let isNew: Bool
        let textView: EditingTextView
        var toolbarStyle: ToolStyle
        var appliedStyle: AnnotationStyle
    }

    private var session: Session?
    /// Identifies the style observation of the current session; stale ones stop on their next change.
    private var styleObservation = 0

    /// Caret room past the last glyph, in points.
    private static let trailingPadding: CGFloat = 2
    private static let selectionAlpha: CGFloat = 0.35

    init(canvas: CanvasView, model: DocumentModel, toolbar: ToolbarModel) {
        self.canvas = canvas
        self.model = model
        self.toolbar = toolbar
    }

    var textView: NSTextView? { session?.textView }
    var isEditing: Bool { session != nil }

    func beginNew(at point: CGPoint) {
        commit()
        let style = toolbar.settings.style(for: .text)
        let origin = CGPoint(x: point.x, y: point.y - TextStyle.lineHeight(fontSize: style.thickness) / 2)
        let annotation = Annotation(
            style: AnnotationStyle(color: style.color, thickness: style.thickness),
            shape: .text(TextContent(origin: origin, string: "")))
        model.beginGesture()
        model.updateGesture { $0.annotations.append(annotation) }
        start(annotationID: annotation.id, isNew: true, caretAt: nil)
    }

    /// `point` (document coordinates) places the caret; nil puts it at the end.
    func beginEditing(annotationID: UUID, at point: CGPoint? = nil) {
        commit()
        guard model.document.annotations.contains(where: { $0.id == annotationID && $0.isText }) else { return }
        model.beginGesture()
        start(annotationID: annotationID, isNew: false, caretAt: point)
    }

    func canvasOriginDidChange() {
        layoutTextView()
    }

    /// Follows style edits made to the annotation outside the text view, e.g. through a selection.
    func documentDidChange() {
        guard var session, let annotation = annotation(session.annotationID),
              annotation.style != session.appliedStyle else { return }
        session.appliedStyle = annotation.style
        self.session = session
        apply(annotation.style, to: session.textView)
        layoutTextView()
    }

    func commit() {
        guard let session else { return }
        self.session = nil
        let textView = session.textView
        textView.delegate = nil
        textView.removeFromSuperview()
        // Commit can run inside the text view's own event handling; keep it alive until that returns.
        Task { @MainActor in withExtendedLifetime(textView) {} }
        canvas.window?.makeFirstResponder(canvas)

        let id = session.annotationID
        let isEmpty = annotation(id).map { text(of: $0).isEmpty } ?? true
        switch (session.isNew, isEmpty) {
        case (true, true):
            model.cancelGesture()
        case (false, true):
            model.updateGesture { $0.annotations.removeAll { $0.id == id } }
            model.endGesture("Delete Text")
        default:
            model.endGesture("Typing")
        }
    }

    // MARK: - Session

    private func start(annotationID: UUID, isNew: Bool, caretAt point: CGPoint?) {
        guard let annotation = annotation(annotationID) else { return model.cancelGesture() }
        let textView = EditingTextView(frame: .zero)
        configure(textView)
        session = Session(
            annotationID: annotationID, isNew: isNew, textView: textView,
            toolbarStyle: toolbar.settings.style(for: .text), appliedStyle: annotation.style)
        textView.string = text(of: annotation)
        apply(annotation.style, to: textView)
        layoutTextView()
        canvas.addSubview(textView)
        canvas.window?.makeFirstResponder(textView)
        let canvasOrigin = model.document.canvasRect.origin
        let caret = point.map {
            textView.characterIndexForInsertion(
                at: textView.convert(CGPoint(x: $0.x - canvasOrigin.x, y: $0.y - canvasOrigin.y), from: canvas))
        }
        textView.setSelectedRange(NSRange(location: caret ?? (textView.string as NSString).length, length: 0))
        textView.delegate = self
        styleObservation += 1
        observeToolbarStyle()
    }

    private func configure(_ textView: EditingTextView) {
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = false
        textView.usesFindBar = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.textContainerInset = .zero
        if let container = textView.textContainer {
            container.lineFragmentPadding = 0
            container.widthTracksTextView = false
            container.heightTracksTextView = false
            container.size = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        }
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor.withAlphaComponent(Self.selectionAlpha),
        ]
        textView.onCommit = { [weak self] in self?.commit() }
        textView.onUndo = { [weak self] redo in
            guard let self else { return }
            commit()
            if redo { model.undoManager.redo() } else { model.undoManager.undo() }
        }
        textView.validateUndo = { [weak self] redo, item in
            guard let self else { return false }
            let undoManager = model.undoManager
            let pending = hasPendingEdit
            if redo {
                item?.title = undoManager.redoMenuItemTitle
                return !pending && undoManager.canRedo
            }
            item?.title = undoManager.undoMenuTitle(forUndoActionName: pending ? "Typing" : undoManager.undoActionName)
            return pending || undoManager.canUndo
        }
    }

    private func apply(_ style: AnnotationStyle, to textView: NSTextView) {
        let font = TextStyle.font(size: style.thickness) as NSFont
        let lineHeight = TextStyle.lineHeight(fontSize: style.thickness)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor.clear, .paragraphStyle: paragraph,
        ]
        textView.font = font
        textView.insertionPointColor = NSColor(cgColor: style.color.cgColor) ?? .textColor
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = attributes
        if let storage = textView.textStorage {
            storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
        }
    }

    private func layoutTextView() {
        guard let session, let annotation = annotation(session.annotationID),
              case .text(let content) = annotation.shape else { return }
        let fontSize = annotation.style.thickness
        let size = TextLayout.layout(string: content.string, fontSize: fontSize).size
        let canvasOrigin = model.document.canvasRect.origin
        session.textView.frame = CGRect(
            x: content.origin.x - canvasOrigin.x, y: content.origin.y - canvasOrigin.y,
            width: max(size.width, fontSize) + Self.trailingPadding, height: size.height)
    }

    // MARK: - Updates

    func textDidChange(_ notification: Notification) {
        guard let session else { return }
        let id = session.annotationID
        let string = session.textView.string
        model.updateGesture { document in
            guard let index = document.annotations.firstIndex(where: { $0.id == id }),
                  case .text(var content) = document.annotations[index].shape else { return }
            content.string = string
            document.annotations[index].shape = .text(content)
            document.annotations[index].extendsCanvas = true
        }
        layoutTextView()
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        commit()
        return true
    }

    private func observeToolbarStyle() {
        let observation = styleObservation
        withObservationTracking {
            _ = toolbar.settings.style(for: .text)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, observation == self.styleObservation else { return }
                self.toolbarStyleDidChange()
            }
        }
    }

    private func toolbarStyleDidChange() {
        guard var session else { return }
        observeToolbarStyle()
        let style = toolbar.settings.style(for: .text)
        guard style != session.toolbarStyle else { return }
        session.toolbarStyle = style
        self.session = session
        let id = session.annotationID
        model.updateGesture { document in
            guard let index = document.annotations.firstIndex(where: { $0.id == id }) else { return }
            document.annotations[index].style = AnnotationStyle(color: style.color, thickness: style.thickness)
            document.annotations[index].extendsCanvas = true
        }
        if let annotation = annotation(id) { apply(annotation.style, to: session.textView) }
        layoutTextView()
        if canvas.window?.firstResponder !== session.textView {
            canvas.window?.makeFirstResponder(session.textView)
        }
    }

    // MARK: - Helpers

    /// Whether committing now would add an undo step.
    private var hasPendingEdit: Bool {
        guard let session else { return false }
        if session.isNew, annotation(session.annotationID).map({ text(of: $0).isEmpty }) ?? true { return false }
        return model.gestureHasChanges
    }

    private func annotation(_ id: UUID) -> Annotation? {
        model.document.annotations.first { $0.id == id }
    }

    private func text(of annotation: Annotation) -> String {
        if case .text(let content) = annotation.shape { content.string } else { "" }
    }
}

/// Routes undo to the document: the edit is committed first, then undone as one step.
final class EditingTextView: NSTextView, UndoActions {
    var onCommit: (() -> Void)?
    /// The flag is true for redo.
    var onUndo: ((Bool) -> Void)?
    var validateUndo: ((Bool, NSMenuItem?) -> Bool)?

    private static let returnKeyCodes: Set<UInt16> = [36, 76]

    override func keyDown(with event: NSEvent) {
        if Self.returnKeyCodes.contains(event.keyCode), event.modifierFlags.contains(.command) {
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }

    func undo(_ sender: Any?) { onUndo?(false) }
    func redo(_ sender: Any?) { onUndo?(true) }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        validateUndoItem(item) ?? super.validateUserInterfaceItem(item)
    }

    override func validateMenuItem(_ item: NSMenuItem) -> Bool {
        validateUndoItem(item) ?? super.validateMenuItem(item)
    }

    private func validateUndoItem(_ item: any NSValidatedUserInterfaceItem) -> Bool? {
        switch item.action {
        case #selector(UndoActions.undo(_:)): validateUndo?(false, item as? NSMenuItem) ?? false
        case #selector(UndoActions.redo(_:)): validateUndo?(true, item as? NSMenuItem) ?? false
        default: nil
        }
    }
}
