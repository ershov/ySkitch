import AppKit

@MainActor
public enum YSkitchApp {
    private static let delegate = AppDelegate()

    public static func run() {
        NSWindow.allowsAutomaticWindowTabbing = false
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
