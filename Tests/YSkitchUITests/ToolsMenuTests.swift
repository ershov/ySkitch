import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct ToolsMenuTests {
    private let settings = ToolSettings.inMemory()

    private func toolsMenu() throws -> NSMenu {
        try #require(MainMenu.build().items.first { $0.submenu?.title == "Tools" }?.submenu)
    }

    private func colorMenu() throws -> NSMenu {
        try #require(toolsMenu().items.first { $0.title == "Color" }?.submenu)
    }

    private func item(_ title: String, in menu: NSMenu) throws -> NSMenuItem {
        try #require(menu.items.first { $0.title == title })
    }

    private func makeController(tool: Tool = .arrow) -> DocumentWindowController {
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 400, height: 300), scale: 1), title: "Test",
            toolSettings: settings)
        controller.toolbar.activeTool = tool
        return controller
    }

    @Test func structure() throws {
        let titles = try toolsMenu().items.map { $0.isSeparatorItem ? "-" : $0.title }
        #expect(titles == [
            "Select", "-", "Text", "-", "Arrow", "Line", "Rectangle", "Rounded Rectangle", "Ellipse", "-",
            "Pen", "Highlighter", "-", "Pixelate", "-", "Crop", "-",
            "Color", "Thinner", "Thicker", "-", "Apply Crop", "Cancel Crop",
        ])
        #expect(try colorMenu().items.map(\.title) == Palette.names)
    }

    @Test func keyEquivalents() throws {
        let tools = try toolsMenu()
        var cases: [(NSMenuItem, String, Selector)] = try Tool.allCases.map {
            (try item($0.name, in: tools), $0.key.lowercased(), #selector(DocumentWindowController.performToolShortcut(_:)))
        }
        cases += try colorMenu().items.enumerated().map {
            ($1, "\($0 + 1)", #selector(DocumentWindowController.performToolShortcut(_:)))
        }
        cases += [
            (try item("Thinner", in: tools), "[", #selector(DocumentWindowController.performToolShortcut(_:))),
            (try item("Thicker", in: tools), "]", #selector(DocumentWindowController.performToolShortcut(_:))),
            (try item("Apply Crop", in: tools), "\r", #selector(DocumentWindowController.applyCrop(_:))),
            (try item("Cancel Crop", in: tools), "\u{1b}", #selector(DocumentWindowController.cancelCrop(_:))),
        ]
        for (item, key, action) in cases {
            #expect(item.keyEquivalent == key, "\(item.title) key")
            #expect(item.keyEquivalentModifierMask == [], "\(item.title) modifiers")
            #expect(item.action == action, "\(item.title) action")
            #expect(item.target == nil, "\(item.title) target")
        }
        #expect(try colorMenu().items.allSatisfy { $0.image != nil })
    }

    @Test func toolItemsSwitchToolAndCheckActive() throws {
        let controller = makeController()
        defer { controller.close() }
        let tools = try toolsMenu()
        for tool in Tool.allCases where tool != .crop {
            let item = try item(tool.name, in: tools)
            controller.performToolShortcut(item)
            #expect(controller.toolbar.activeTool == tool)
            for other in Tool.allCases {
                let otherItem = try self.item(other.name, in: tools)
                #expect(controller.validateMenuItem(otherItem))
                #expect(otherItem.state == (other == tool ? .on : .off), "\(other.name) with \(tool.name)")
            }
        }
    }

    @Test func colorItems() throws {
        let controller = makeController()
        defer { controller.close() }
        let colors = try colorMenu().items
        func checked() -> [Int] {
            colors.indices.filter { _ = controller.validateMenuItem(colors[$0]); return colors[$0].state == .on }
        }
        #expect(colors.allSatisfy { controller.validateMenuItem($0) })
        #expect(checked() == [Palette.defaultColorIndex])

        controller.performToolShortcut(colors[0])
        #expect(controller.toolbar.currentStyle.color == Palette.colors[0])
        #expect(checked() == [0])

        for tool in [Tool.select, .pixelate, .crop] {
            controller.toolbar.activeTool = tool
            #expect(colors.allSatisfy { !controller.validateMenuItem($0) }, "\(tool.name)")
            #expect(checked().isEmpty, "\(tool.name)")
        }
    }

    @Test func colorItemsFollowSelection() throws {
        let controller = makeController(tool: .select)
        defer { controller.close() }
        let style = AnnotationStyle(color: Palette.colors[2], thickness: 10)
        controller.model.perform("Add") {
            $0.annotations = [
                Annotation(style: style, shape: .pixelate(CGRect(x: 10, y: 10, width: 50, height: 50))),
                Annotation(style: style, shape: .rectangle(CGRect(x: 100, y: 100, width: 50, height: 50))),
            ]
        }
        let colors = try colorMenu().items
        controller.selection.select([controller.model.document.annotations[1].id])
        #expect(controller.validateMenuItem(colors[2]))
        #expect(colors[2].state == .on)
        controller.selection.select([controller.model.document.annotations[0].id])
        #expect(!controller.validateMenuItem(colors[2]))
        #expect(colors[2].state == .off)
        controller.performToolShortcut(colors[0])
        #expect(controller.model.document.annotations[0].style.color == Palette.colors[2])
    }

    @Test func thicknessItems() throws {
        let controller = makeController()
        defer { controller.close() }
        let tools = try toolsMenu()
        let thinner = try item("Thinner", in: tools)
        let thicker = try item("Thicker", in: tools)
        controller.performToolShortcut(thicker)
        #expect(controller.toolbar.currentStyle.thickness > Tool.strokeDefault)
        controller.performToolShortcut(thinner)
        controller.performToolShortcut(thinner)
        #expect(controller.toolbar.currentStyle.thickness < Tool.strokeDefault)
        for tool in Tool.allCases {
            controller.toolbar.activeTool = tool
            #expect(controller.validateMenuItem(thinner) == (tool.thicknessRange != nil), "\(tool.name)")
            #expect(controller.validateMenuItem(thicker) == (tool.thicknessRange != nil), "\(tool.name)")
            #expect(thinner.state == .off)
        }
    }

    @Test func cropItemsOnlyWhileCropping() throws {
        let controller = makeController()
        defer { controller.close() }
        let tools = try toolsMenu()
        let apply = try item("Apply Crop", in: tools)
        let cancel = try item("Cancel Crop", in: tools)
        #expect(!controller.validateMenuItem(apply))
        #expect(!controller.validateMenuItem(cancel))

        controller.performToolShortcut(try item("Crop", in: tools))
        #expect(controller.canvasView.isCropping)
        #expect(controller.validateMenuItem(apply))
        #expect(controller.validateMenuItem(cancel))
        controller.cancelCrop(cancel)
        #expect(!controller.canvasView.isCropping)
        #expect(controller.toolbar.activeTool == .arrow)
        #expect(controller.model.document.canvasRect.size == CGSize(width: 400, height: 300))

        controller.toolbar.activeTool = .crop
        controller.applyCrop(apply)
        #expect(!controller.canvasView.isCropping)
        #expect(controller.toolbar.activeTool == .arrow)
        #expect(controller.model.undoManager.undoActionName == "Crop")
        #expect(!controller.validateMenuItem(apply))
    }

    /// The text view consumes plain keys, so AppKit never offers them to the menu while editing.
    @Test func singleKeysTypeIntoTextAnnotation() throws {
        let controller = makeController(tool: .text)
        defer { controller.close() }
        let window = try #require(controller.window)
        let view = controller.canvasView
        let point = view.convert(CGPoint(x: 50, y: 60), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            type == .leftMouseDown ? view.mouseDown(with: event) : view.mouseUp(with: event)
        }
        let textView = try #require(view.textEditor.textView)
        #expect(window.firstResponder === textView)

        func press(_ characters: String, keyCode: UInt16) throws {
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode))
            window.sendEvent(event)
        }

        let style = controller.toolbar.settings.style(for: .text)
        for (characters, keyCode) in [("a", UInt16(0)), ("c", 8), ("1", 18), ("]", 30), ("[", 33), ("\r", 36)] {
            try press(characters, keyCode: keyCode)
        }
        #expect(textView.string == "ac1][\n")
        #expect(controller.toolbar.activeTool == .text)
        #expect(controller.toolbar.settings.style(for: .text) == style)

        try press("\u{1b}", keyCode: 53)
        #expect(!view.textEditor.isEditing)
        #expect(controller.toolbar.activeTool == .text)
    }
}
