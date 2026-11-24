import Foundation
import Observation
import YSkitchCore

/// Per-window tool selection; styles are shared through `ToolSettings`.
/// With a non-empty selection, the style controls show and edit the selection instead of the tool defaults.
@MainActor @Observable
final class ToolbarModel {
    @ObservationIgnored let settings: ToolSettings
    @ObservationIgnored weak var selection: SelectionModel?

    var activeTool: Tool {
        didSet {
            if oldValue != activeTool { previousTool = oldValue }
            // Crop is a transient mode; a new window never starts in it.
            if activeTool != .crop { settings.preferences.lastTool = activeTool }
            if activeTool != .select { selection?.clear() }
            onActiveToolChange?()
        }
    }

    @ObservationIgnored var onActiveToolChange: (() -> Void)?

    /// The tool that was active before the current one.
    @ObservationIgnored private(set) var previousTool: Tool = .select

    init(settings: ToolSettings) {
        self.settings = settings
        activeTool = settings.preferences.lastTool
    }

    /// Style for the next drawn annotation.
    var currentStyle: ToolStyle { settings.style(for: activeTool) }

    private var selectionStyle: SelectionModel.Style? { selection?.style }

    /// The tool whose style controls are shown.
    var styleTool: Tool { selectionStyle?.tool ?? activeTool }

    var displayedStyle: ToolStyle { selectionStyle?.style ?? currentStyle }

    func selectColor(index: Int) {
        guard Palette.colors.indices.contains(index), styleTool.usesColor else { return }
        if let selection, selectionStyle != nil {
            selection.setColor(Palette.colors[index])
            adoptSelectionStyles(color: true, thickness: false)
            return
        }
        settings.setColor(Palette.colors[index], for: activeTool)
    }

    func setThickness(_ thickness: CGFloat) {
        if let selection, selectionStyle != nil {
            selection.setThickness(thickness)
            adoptSelectionStyles(color: false, thickness: true)
            return
        }
        settings.setThickness(thickness, for: activeTool)
    }

    func stepThickness(by steps: Int) {
        if let selection, selectionStyle != nil {
            selection.stepThickness(by: steps)
            adoptSelectionStyles(color: false, thickness: true)
            return
        }
        guard let range = activeTool.thicknessRange else { return }
        setThickness(ThicknessScale.stepped(currentStyle.thickness, in: range, by: steps))
    }

    /// Makes the edited selection's styles the defaults of their tools (applied on every edit, including each slider step).
    private func adoptSelectionStyles(color: Bool, thickness: Bool) {
        for annotation in selection?.selectedAnnotations ?? [] {
            let tool = annotation.shape.tool
            if color, tool.usesColor { settings.setColor(annotation.style.color, for: tool) }
            if thickness { settings.setThickness(annotation.style.thickness, for: tool) }
        }
    }

    /// Brackets a slider drag so a selection edit is one undo step.
    func beginThicknessDrag() { selection?.beginStyleGesture() }

    func endThicknessDrag() { selection?.endStyleGesture() }

    /// Whether `action` applies to the shown style controls.
    func canPerform(_ action: ToolShortcut.Action) -> Bool {
        switch action {
        case .tool: true
        case .color: styleTool.usesColor
        case .thicknessStep: styleTool.thicknessRange != nil
        }
    }

    /// Whether `action` selects the active tool or the shown color.
    func isCurrent(_ action: ToolShortcut.Action) -> Bool {
        switch action {
        case .tool(let tool): activeTool == tool
        case .color(let index): styleTool.usesColor && displayedStyle.color == Palette.colors[index]
        case .thicknessStep: false
        }
    }

    func perform(_ action: ToolShortcut.Action) {
        switch action {
        case .tool(let tool): activeTool = tool
        case .color(let index): selectColor(index: index)
        case .thicknessStep(let steps): stepThickness(by: steps)
        }
    }
}
