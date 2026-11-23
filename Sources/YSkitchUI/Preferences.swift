import Foundation
import YSkitchCore

protocol PreferencesStore: AnyObject {
    func string(forKey key: String) -> String?
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: PreferencesStore {}

final class InMemoryPreferencesStore: PreferencesStore {
    private var values: [String: Any] = [:]

    func string(forKey key: String) -> String? { values[key] as? String }
    func data(forKey key: String) -> Data? { values[key] as? Data }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
    }

    func removeObject(forKey key: String) {
        values[key] = nil
    }
}

@MainActor
final class Preferences {
    static let shared = Preferences()

    private let defaults: PreferencesStore

    init(store: PreferencesStore = UserDefaults.standard) {
        self.defaults = store
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
