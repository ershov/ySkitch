import AppKit
import YSkitchCore

@MainActor
enum MainMenu {
    static let appName = "ySkitch"

    static func build() -> NSMenu {
        let main = NSMenu()
        for menu in [appMenu(), fileMenu(), editMenu(), toolsMenu(), viewMenu(), windowMenu(), helpMenu()] {
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
        menu.addItem(item("Reopen Closed Window", #selector(AppDelegate.reopenClosedWindow(_:)), "t", [.command, .shift]))
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
        menu.addItem(item("Cut", #selector(DocumentWindowController.cut(_:)), "x"))
        menu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Copy Image", #selector(DocumentWindowController.copyImage(_:)), "c", [.command, .shift]))
        menu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        menu.addItem(item("Duplicate", #selector(DocumentWindowController.duplicate(_:)), "d"))
        menu.addItem(item("Delete", #selector(NSText.delete(_:))))
        menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        menu.addItem(.separator())
        let nudge = NSMenuItem(title: "Nudge", action: nil, keyEquivalent: "")
        nudge.submenu = nudgeMenu()
        menu.addItem(nudge)
        return menu
    }

    private static func nudgeMenu() -> NSMenu {
        let menu = NSMenu(title: "Nudge")
        for direction in NudgeDirection.allCases {
            let key = direction.keyEquivalent
            let name = direction.name
            let small = item(name, #selector(DocumentWindowController.nudge(_:)), key, [])
            small.representedObject = direction.vector(large: false)
            let large = item("Nudge \(name) \(Int(NudgeDirection.largeStep)) pt", #selector(DocumentWindowController.nudge(_:)), key, [.shift])
            large.representedObject = direction.vector(large: true)
            large.isAlternate = true
            menu.addItem(small)
            menu.addItem(large)
        }
        return menu
    }

    /// Keys without modifiers: AppKit offers them to the menu only when the focused view does not handle them.
    private static func toolsMenu() -> NSMenu {
        let menu = NSMenu(title: "Tools")
        for (index, group) in Tool.groups.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for tool in group { menu.addItem(shortcutItem(tool.name, .tool(tool))) }
        }
        menu.addItem(.separator())
        let colors = NSMenu(title: "Color")
        for (index, name) in Palette.names.enumerated() {
            let item = shortcutItem(name, .color(index))
            item.image = swatch(Palette.colors[index])
            colors.addItem(item)
        }
        let color = NSMenuItem(title: colors.title, action: nil, keyEquivalent: "")
        color.submenu = colors
        menu.addItem(color)
        menu.addItem(shortcutItem("Thinner", .thicknessStep(-1)))
        menu.addItem(shortcutItem("Thicker", .thicknessStep(1)))
        menu.addItem(.separator())
        menu.addItem(item("Apply Crop", #selector(DocumentWindowController.applyCrop(_:)), "\r", []))
        menu.addItem(item("Cancel Crop", #selector(DocumentWindowController.cancelCrop(_:)), "\u{1b}", []))
        return menu
    }

    private static func shortcutItem(_ title: String, _ action: ToolShortcut.Action) -> NSMenuItem {
        item(title, #selector(DocumentWindowController.performToolShortcut(_:)), ToolShortcut.key(for: action), [])
    }

    private static func swatch(_ color: RGBAColor) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            NSColor(cgColor: color.cgColor)?.setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.stroke()
            return true
        }
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
