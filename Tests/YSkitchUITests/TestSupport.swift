@testable import YSkitchUI

extension ToolSettings {
    /// Backed by an in-memory store; tests never touch `UserDefaults`.
    static func inMemory() -> ToolSettings {
        ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
    }
}
