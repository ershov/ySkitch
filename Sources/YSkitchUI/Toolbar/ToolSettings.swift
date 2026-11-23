import Foundation
import Observation
import YSkitchCore

/// App-wide per-tool styles, persisted in `Preferences`.
@MainActor @Observable
final class ToolSettings {
    static let shared = ToolSettings(preferences: .shared)

    @ObservationIgnored let preferences: Preferences

    var styles: ToolStyles {
        didSet { preferences.toolStyles = styles }
    }

    init(preferences: Preferences) {
        self.preferences = preferences
        styles = preferences.toolStyles
    }

    func style(for tool: Tool) -> ToolStyle { styles[tool] }

    func setColor(_ color: RGBAColor, for tool: Tool) {
        styles[tool].color = color
    }

    func setThickness(_ thickness: CGFloat, for tool: Tool) {
        guard let range = tool.thicknessRange else { return }
        styles[tool].thickness = min(max(thickness, range.lowerBound), range.upperBound)
    }
}
