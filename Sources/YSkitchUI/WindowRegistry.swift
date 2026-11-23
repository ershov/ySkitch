import AppKit
import YSkitchCore

@MainActor
final class WindowRegistry {
    static let shared = WindowRegistry()

    let closedWindows = ClosedWindowHistory()
    private(set) var controllers: [DocumentWindowController] = []
    private var cascadePoint = NSPoint.zero
    private var closeObservers: [ObjectIdentifier: any NSObjectProtocol] = [:]

    @discardableResult
    func openFromPasteboard(_ pasteboard: NSPasteboard) -> DocumentWindowController {
        let fileURL = (pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
        ) as? [URL])?.first
        let title = DocumentNaming.title(sourceURL: fileURL, date: .now)
        if let image = PasteboardImageReader.read(from: pasteboard) {
            return show(Document(image: image), title: title)
        }
        return show(Self.blankDocument(), title: title)
    }

    @discardableResult
    func openBlank() -> DocumentWindowController {
        show(Self.blankDocument(), title: DocumentNaming.title(sourceURL: nil, date: .now))
    }

    @discardableResult
    func open(url: URL) throws -> DocumentWindowController {
        let image = try ImageImporter.load(url: url)
        return show(Document(image: image), title: DocumentNaming.title(sourceURL: url, date: .now))
    }

    @discardableResult
    func openDropped(_ pasteboard: NSPasteboard) -> Bool {
        let urls = PasteboardImageReader.imageFileURLs(in: pasteboard)
        if !urls.isEmpty {
            return urls.reduce(false) { opened, url in ((try? open(url: url)) != nil) || opened }
        }
        guard let image = PasteboardImageReader.read(from: pasteboard) else { return false }
        show(Document(image: image), title: DocumentNaming.title(sourceURL: nil, date: .now))
        return true
    }

    private static func blankDocument() -> Document {
        Document(blankSize: CGSize(width: 1024, height: 768), scale: NSScreen.main?.backingScaleFactor ?? 2)
    }

    @discardableResult
    private func show(_ document: Document, title: String) -> DocumentWindowController {
        let controller = DocumentWindowController(document: document, title: title)
        guard let window = controller.window else { return controller }
        if controllers.isEmpty {
            window.center()
            cascadePoint = .zero
        }
        cascadePoint = window.cascadeTopLeft(from: cascadePoint)
        controller.scrollView.onDrop = { [weak self] in self?.openDropped($0) ?? false }
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
        controller.canvasView.cancelActiveGesture()
        closedWindows.push(ClosedWindowHistory.Entry(controller))
    }

    @discardableResult
    func reopenLastClosed() -> DocumentWindowController? {
        guard let entry = closedWindows.popLast() else { return nil }
        let controller = DocumentWindowController(
            model: entry.model, title: entry.title, savedURL: entry.savedURL)
        guard let window = controller.window else { return controller }
        window.setFrame(entry.frame, display: false)
        window.contentView?.layoutSubtreeIfNeeded()
        let scrollView = controller.scrollView
        scrollView.magnification = entry.magnification
        scrollView.contentView.scroll(to: entry.scrollOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        if controller.toolbar.activeTool != entry.tool { controller.toolbar.activeTool = entry.tool }
        scrollView.onDrop = { [weak self] in self?.openDropped($0) ?? false }
        register(controller, window: window)
        controller.showWindow(nil)
        return controller
    }
}
