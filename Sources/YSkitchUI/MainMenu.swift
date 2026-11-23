import AppKit

@MainActor
enum MainMenu {
    static let appName = "ySkitch"

    static func build() -> NSMenu {
        let main = NSMenu()
        for menu in [appMenu(), fileMenu(), editMenu(), viewMenu(), windowMenu(), helpMenu()] {
            let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
            item.submenu = menu
            main.addItem(item)
        }
        return main
    }

    static func install() {
        let menu = build()
        NSApp.mainMenu = menu
        NSApp.windowsMenu = menu.items.first { $0.submenu?.title == "Window" }?.submenu
        NSApp.helpMenu = menu.items.first { $0.submenu?.title == "Help" }?.submenu
    }

    private static func item(
        _ title: String, _ action: Selector?, _ key: String = "",
        _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { item.keyEquivalentModifierMask = modifiers }
        return item
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: appName)
        menu.addItem(item("About \(appName)", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Hide \(appName)", #selector(NSApplication.hide(_:)), "h"))
        menu.addItem(item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        menu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Quit \(appName)", #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(item("New", #selector(AppDelegate.newDocument(_:)), "n"))
        menu.addItem(item("New Blank", #selector(AppDelegate.newBlankDocument(_:)), "n", [.command, .shift]))
        menu.addItem(item("Open…", #selector(AppDelegate.openDocument(_:)), "o"))
        menu.addItem(.separator())
        menu.addItem(item("Save", #selector(DocumentWindowController.saveDocument(_:)), "s"))
        menu.addItem(item("Save As…", #selector(DocumentWindowController.saveDocumentAs(_:)), "s", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Close", #selector(NSWindow.performClose(_:)), "w"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(item("Undo", #selector(UndoActions.undo(_:)), "z"))
        menu.addItem(item("Redo", #selector(UndoActions.redo(_:)), "z", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        menu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Copy Image", #selector(DocumentWindowController.copyImage(_:)), "c", [.command, .shift]))
        menu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        menu.addItem(item("Delete", #selector(NSText.delete(_:))))
        menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        menu.addItem(item("Zoom In", #selector(DocumentWindowController.zoomIn(_:)), "+"))
        let zoomInWithoutShift = item("Zoom In", #selector(DocumentWindowController.zoomIn(_:)), "=")
        zoomInWithoutShift.isHidden = true
        zoomInWithoutShift.allowsKeyEquivalentWhenHidden = true
        menu.addItem(zoomInWithoutShift)
        menu.addItem(item("Zoom Out", #selector(DocumentWindowController.zoomOut(_:)), "-"))
        menu.addItem(item("Actual Size", #selector(DocumentWindowController.zoomToActualSize(_:)), "0"))
        menu.addItem(item("Zoom to Fit", #selector(DocumentWindowController.zoomToFit(_:)), "9"))
        menu.addItem(.separator())
        menu.addItem(item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"))
        menu.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))))
        return menu
    }

    private static func helpMenu() -> NSMenu {
        NSMenu(title: "Help")
    }
}

/// Standard undo actions; `NSWindow` implements them without declaring them to Swift.
@MainActor @objc protocol UndoActions {
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
}
