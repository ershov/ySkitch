import AppKit
import YSkitchCore

@MainActor
final class WindowRegistry {
    static let shared = WindowRegistry()

    private(set) var controllers: [DocumentWindowController] = []
    private var cascadePoint = NSPoint.zero
    private var closeObservers: [ObjectIdentifier: any NSObjectProtocol] = [:]

    @discardableResult
    func openNewDocument(_ document: Document? = nil) -> DocumentWindowController {
        let controller = DocumentWindowController(document: document ?? DocumentWindowController.blankDocument())
        guard let window = controller.window else { return controller }
        if controllers.isEmpty {
            window.center()
            cascadePoint = .zero
        }
        cascadePoint = window.cascadeTopLeft(from: cascadePoint)
        register(controller, window: window)
        controller.showWindow(nil)
        return controller
    }

    private func register(_ controller: DocumentWindowController, window: NSWindow) {
        controllers.append(controller)
        let id = ObjectIdentifier(controller)
        closeObservers[id] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self, weak controller] _ in
            MainActor.assumeIsolated {
                guard let self, let controller else { return }
                self.unregister(controller)
            }
        }
    }

    private func unregister(_ controller: DocumentWindowController) {
        let id = ObjectIdentifier(controller)
        if let observer = closeObservers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
        controllers.removeAll { $0 === controller }
    }
}
