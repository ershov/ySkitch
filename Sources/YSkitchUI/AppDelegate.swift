import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let registry: WindowRegistry

    init(registry: WindowRegistry = .shared) {
        self.registry = registry
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainMenu.install()
        DispatchQueue.main.async { [registry] in
            if registry.controllers.isEmpty { registry.openFromPasteboard(.general) }
        }
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { registry.openFromPasteboard(.general) }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        open(urls)
    }

    @objc func newDocument(_ sender: Any?) {
        registry.openFromPasteboard(.general)
    }

    @objc func newBlankDocument(_ sender: Any?) {
        registry.openBlank()
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        open(panel.urls)
    }

    @objc func reopenClosedWindow(_ sender: Any?) {
        registry.reopenLastClosed()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        item.action == #selector(reopenClosedWindow(_:)) ? !registry.closedWindows.isEmpty : true
    }

    private func open(_ urls: [URL]) {
        for url in urls {
            do {
                try registry.open(url: url)
            } catch {
                let alert = NSAlert()
                alert.messageText = "“\(url.lastPathComponent)” couldn't be opened."
                alert.informativeText = "The file is not a supported image."
                alert.runModal()
            }
        }
    }
}
