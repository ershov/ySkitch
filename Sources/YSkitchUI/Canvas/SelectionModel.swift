import Foundation
import Observation
import YSkitchCore

/// Per-window selection; not part of the document or its undo history.
@MainActor @Observable
final class SelectionModel {
    struct Style: Equatable {
        /// Determines the thickness range and whether color applies.
        var tool: Tool
        var style: ToolStyle
    }

    @ObservationIgnored let model: DocumentModel
    @ObservationIgnored var onChange: (() -> Void)?

    /// Selection order; the first one drives the toolbar.
    private(set) var selectedIDs: [UUID] = [] {
        didSet {
            guard selectedIDs != oldValue else { return }
            refreshStyle()
            onChange?()
        }
    }

    /// Style of the first selected annotation.
    private(set) var style: Style?

    @ObservationIgnored private var ownsStyleGesture = false

    init(model: DocumentModel) {
        self.model = model
    }

    var isEmpty: Bool { selectedIDs.isEmpty }

    func contains(_ id: UUID) -> Bool { selectedIDs.contains(id) }

    var selectedAnnotations: [Annotation] {
        let annotations = model.document.annotations
        return selectedIDs.compactMap { id in annotations.first { $0.id == id } }
    }

    func select(_ ids: [UUID]) {
        var seen = Set<UUID>()
        selectedIDs = ids.filter { seen.insert($0).inserted }
    }

    func toggle(_ id: UUID) {
        if contains(id) { selectedIDs.removeAll { $0 == id } } else { selectedIDs.append(id) }
    }

    func clear() { selectedIDs = [] }

    func selectAll() { select(model.document.annotations.map(\.id)) }

    func documentDidChange() {
        let existing = Set(model.document.annotations.map(\.id))
        let kept = selectedIDs.filter(existing.contains)
        if kept != selectedIDs { selectedIDs = kept } else { refreshStyle() }
    }

    // MARK: - Editing

    func deleteSelected(actionName: String = "Delete") {
        let ids = Set(selectedIDs)
        guard !ids.isEmpty else { return }
        model.perform(actionName) { $0.annotations.removeAll { ids.contains($0.id) } }
    }

    func setColor(_ color: RGBAColor) {
        edit("Change Color") { $0.withStyle(color: color) }
    }

    /// Clamped per annotation to its kind's range.
    func setThickness(_ thickness: CGFloat) {
        edit("Change Thickness") { $0.withStyle(thickness: thickness) }
    }

    /// Steps each annotation's own thickness within its kind's range.
    func stepThickness(by steps: Int) {
        edit("Change Thickness") { annotation in
            guard let range = annotation.shape.tool.thicknessRange else { return annotation }
            return annotation.withStyle(
                thickness: ThicknessScale.stepped(annotation.style.thickness, in: range, by: steps))
        }
    }

    /// Coalesces the style changes until `endStyleGesture()` into one undo step.
    func beginStyleGesture() {
        guard !isEmpty, !model.isInGesture else { return }
        model.beginGesture()
        ownsStyleGesture = true
    }

    func endStyleGesture() {
        guard ownsStyleGesture else { return }
        ownsStyleGesture = false
        model.endGesture("Change Thickness")
    }

    /// Edits inside a running gesture join that gesture's undo step.
    private func edit(_ actionName: String, _ transform: (Annotation) -> Annotation) {
        let ids = Set(selectedIDs)
        guard !ids.isEmpty else { return }
        let change: (inout Document) -> Void = { document in
            for index in document.annotations.indices where ids.contains(document.annotations[index].id) {
                let original = document.annotations[index]
                var edited = transform(original)
                guard edited != original else { continue }
                edited.extendsCanvas = true
                document.annotations[index] = edited
            }
        }
        if model.isInGesture { model.updateGesture(change) } else { model.perform(actionName, change) }
    }

    private func refreshStyle() {
        let first = selectedIDs.first.flatMap { id in model.document.annotations.first { $0.id == id } }
        let updated = first.map {
            Style(tool: $0.shape.tool, style: ToolStyle(color: $0.style.color, thickness: $0.style.thickness))
        }
        if updated != style { style = updated }
    }
}
