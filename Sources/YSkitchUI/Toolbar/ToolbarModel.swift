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
            settings.preferences.lastTool = activeTool
            if activeTool != .select { selection?.clear() }
            onActiveToolChange?()
        }
    }

    @ObservationIgnored var onActiveToolChange: (() -> Void)?

    init(settings: ToolSettings = .shared) {
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
        guard Palette.colors.indices.contains(index) else { return }
        if let selection, selectionStyle != nil { return selection.setColor(Palette.colors[index]) }
        guard activeTool.usesColor else { return }
        settings.setColor(Palette.colors[index], for: activeTool)
    }

    func setThickness(_ thickness: CGFloat) {
        if let selection, selectionStyle != nil { return selection.setThickness(thickness) }
        settings.setThickness(thickness, for: activeTool)
    }

    func stepThickness(by steps: Int) {
        if let selection, selectionStyle != nil { return selection.stepThickness(by: steps) }
        guard let range = activeTool.thicknessRange else { return }
        setThickness(ThicknessScale.stepped(currentStyle.thickness, in: range, by: steps))
    }

    /// Brackets a slider drag so a selection edit is one undo step.
    func beginThicknessDrag() { selection?.beginStyleGesture() }

    func endThicknessDrag() { selection?.endStyleGesture() }

    func perform(_ action: ToolShortcut.Action) {
        switch action {
        case .tool(let tool): activeTool = tool
        case .color(let index): selectColor(index: index)
        case .thicknessStep(let steps): stepThickness(by: steps)
        }
    }
}
