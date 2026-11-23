import Foundation
import YSkitchCore

@MainActor
final class Preferences {
    static let shared = Preferences()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastSaveFolder: URL? {
        get {
            defaults.string(forKey: "lastSaveFolder").map { URL(fileURLWithPath: $0, isDirectory: true) }
        }
        set {
            defaults.set(newValue?.path, forKey: "lastSaveFolder")
        }
    }

    var toolStyles: ToolStyles {
        get {
            defaults.data(forKey: "toolStyles").flatMap { try? JSONDecoder().decode(ToolStyles.self, from: $0) }
                ?? ToolStyles()
        }
        set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: "toolStyles")
        }
    }

    var lastTool: Tool {
        get { defaults.string(forKey: "lastTool").flatMap(Tool.init(rawValue:)) ?? .arrow }
        set { defaults.set(newValue.rawValue, forKey: "lastTool") }
    }
}
