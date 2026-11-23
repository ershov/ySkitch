import Foundation
import Observation
import YSkitchCore

/// Per-window tool selection; styles are shared through `ToolSettings`.
@MainActor @Observable
final class ToolbarModel {
    @ObservationIgnored let settings: ToolSettings

    var activeTool: Tool {
        didSet {
            settings.preferences.lastTool = activeTool
            onActiveToolChange?()
        }
    }

    @ObservationIgnored var onActiveToolChange: (() -> Void)?

    init(settings: ToolSettings = .shared) {
        self.settings = settings
        activeTool = settings.preferences.lastTool
    }

    var currentStyle: ToolStyle { settings.style(for: activeTool) }

    func selectColor(index: Int) {
        guard activeTool.usesColor, Palette.colors.indices.contains(index) else { return }
        settings.setColor(Palette.colors[index], for: activeTool)
    }

    func setThickness(_ thickness: CGFloat) {
        settings.setThickness(thickness, for: activeTool)
    }

    func stepThickness(by steps: Int) {
        guard let range = activeTool.thicknessRange else { return }
        setThickness(ThicknessScale.stepped(currentStyle.thickness, in: range, by: steps))
    }

    func perform(_ action: ToolShortcut.Action) {
        switch action {
        case .tool(let tool): activeTool = tool
        case .color(let index): selectColor(index: index)
        case .thicknessStep(let steps): stepThickness(by: steps)
        }
    }
}
