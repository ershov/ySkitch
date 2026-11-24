import AppKit
import YSkitchCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private let registry: WindowRegistry
    private let launchCommand: CommandLineCommand
    private let pasteboard: NSPasteboard
    private let presentProblems: (@MainActor ([OpenProblem]) -> Void)?
    private var commandObserver: (any NSObjectProtocol)?
    private var handledCommandIDs: [String] = []
    private var suppressReopenUntil: Date?

    init(
        registry: WindowRegistry = .shared,
        launchCommand: CommandLineCommand = .open([]),
        pasteboard: NSPasteboard = .general,
        presentProblems: (@MainActor ([OpenProblem]) -> Void)? = nil
    ) {
        self.registry = registry
        self.launchCommand = launchCommand
        self.pasteboard = pasteboard
        self.presentProblems = presentProblems
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DragTempFiles.removeAll()
        MainMenu.install()
        commandObserver = CommandChannel.listen { [weak self] arguments, id in
            self?.handleCommand(arguments: arguments, id: id)
        }
        DispatchQueue.main.async { [self] in performLaunchCommand() }
        NSApp.activate()
    }

    /// Launch arguments open their windows; when they open none, the default new window applies.
    func performLaunchCommand() {
        if case .open(let items) = launchCommand, !items.isEmpty { open(items) }
        if registry.controllers.isEmpty { registry.openFromPasteboard(pasteboard) }
    }

    func handleCommand(arguments: [String], id: String) {
        // The launcher re-posts until acknowledged.
        defer { CommandChannel.acknowledge(id: id) }
        guard !handledCommandIDs.contains(id) else { return }
        handledCommandIDs = Array((handledCommandIDs + [id]).suffix(20))
        switch CommandLineArguments.decode(arguments) {
        case .quit:
            DispatchQueue.main.async { NSApp.terminate(nil) }
        case .open(let items):
            // The launcher activates the app through LaunchServices, which sends a reopen event.
            suppressReopenUntil = Date.now.addingTimeInterval(3)
            open(items)
            NSApplication.shared.activate()
        case .help, .version:
            break
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        DragTempFiles.removeAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let until = suppressReopenUntil, Date.now < until {
            suppressReopenUntil = nil
            return true
        }
        if !flag { registry.openFromPasteboard(pasteboard) }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        open(urls)
    }

    @objc func newDocument(_ sender: Any?) {
        registry.openFromPasteboard(pasteboard)
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
        open(urls.map { .file($0.path(percentEncoded: false)) })
    }

    private func open(_ items: [LaunchItem]) {
        let problems = registry.open(items, pasteboard: pasteboard).problems
        guard !problems.isEmpty else { return }
        // Deferred so a command is acknowledged before an alert can block.
        DispatchQueue.main.async { [self] in
            if let presentProblems { presentProblems(problems) } else { showAlert(problems) }
        }
    }

    /// A sheet, not an app-modal alert: distributed notifications aren't delivered during a modal session,
    /// so further commands would wait until the alert is dismissed.
    private func showAlert(_ problems: [OpenProblem]) {
        guard let text = OpenProblem.alert(for: problems) else { return }
        let alert = NSAlert()
        alert.messageText = text.message
        alert.informativeText = text.information
        if let window = registry.controllers.last?.window {
            alert.beginSheetModal(for: window)
        } else {
            NSApp.activate()
            alert.runModal()
        }
    }
}
