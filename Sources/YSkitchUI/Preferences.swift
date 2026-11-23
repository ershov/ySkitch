import Foundation

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
}
