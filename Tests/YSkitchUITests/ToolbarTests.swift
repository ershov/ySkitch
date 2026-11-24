import AppKit
import Foundation
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct ToolbarTests {
    private let store = InMemoryPreferencesStore()

    @Test func toolSettingsPersist() {
        let settings = ToolSettings(preferences: Preferences(store: store))
        #expect(settings.style(for: .arrow) == ToolStyle.defaultStyle(for: .arrow))
        settings.setColor(Palette.colors[0], for: .arrow)
        settings.setThickness(12, for: .arrow)
        settings.setThickness(500, for: .text)

        let reloaded = ToolSettings(preferences: Preferences(store: store))
        #expect(reloaded.style(for: .arrow) == ToolStyle(color: Palette.colors[0], thickness: 12))
        #expect(reloaded.style(for: .text).thickness == 120)
        #expect(reloaded.style(for: .line) == ToolStyle.defaultStyle(for: .line))
    }

    @Test func colorIsPerTool() {
        let model = ToolbarModel(settings: ToolSettings(preferences: Preferences(store: store)))
        model.activeTool = .arrow
        model.selectColor(index: 4)
        model.activeTool = .line
        #expect(model.currentStyle.color == Palette.defaultColor)
        model.activeTool = .arrow
        #expect(model.currentStyle.color == Palette.colors[4])
    }

    @Test func colorAndThicknessIgnoredWhenUnsupported() {
        let settings = ToolSettings(preferences: Preferences(store: store))
        let model = ToolbarModel(settings: settings)
        model.activeTool = .crop
        model.selectColor(index: 0)
        model.stepThickness(by: 1)
        #expect(settings.styles == ToolStyles())
    }

    @Test func lastToolRemembered() {
        let settings = ToolSettings(preferences: Preferences(store: store))
        #expect(ToolbarModel(settings: settings).activeTool == .arrow)
        ToolbarModel(settings: settings).activeTool = .ellipse
        #expect(ToolbarModel(settings: settings).activeTool == .ellipse)
        #expect(Preferences(store: store).lastTool == .ellipse)
    }

    @Test func symbolsResolve() {
        for tool in Tool.allCases {
            if case .symbol(let name) = ToolIcon.icon(for: tool) {
                #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(tool)")
            }
        }
    }

    @Test func toolbarOccupiesSlot() throws {
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 800, height: 600), scale: 1), title: "Test",
            toolSettings: ToolSettings(preferences: Preferences(store: store)))
        defer { controller.close() }
        let content = try #require(controller.window?.contentView as? DocumentContentView)
        content.layoutSubtreeIfNeeded()
        #expect(content.toolbarSlot.frame.width == ToolbarView.width)
        #expect(content.toolbarSlot.subviews.first is ToolbarHostingView)
        #expect(controller.scrollView.frame.minX == ToolbarView.width)
    }

    @Test func toolbarWidthDrivesChrome() {
        #expect(ToolbarView.width == 140)
        #expect(DocumentWindowController.chromeSize.width == ToolbarView.width)
    }

    @Test func thicknessSliderUsesWedgeCell() throws {
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 800, height: 600), scale: 1), title: "Test",
            toolSettings: ToolSettings(preferences: Preferences(store: store)))
        defer { controller.close() }
        let content = try #require(controller.window?.contentView as? DocumentContentView)
        content.layoutSubtreeIfNeeded()

        func sliders(in view: NSView) -> [NSSlider] {
            (view as? NSSlider).map { [$0] } ?? view.subviews.flatMap(sliders(in:))
        }
        let slider = try #require(sliders(in: content.toolbarSlot).first)
        #expect(slider.cell is WedgeSliderCell)
        #expect(slider.frame.width == ToolbarView.colorColumnWidth)
    }

    @Test func wedgeKnobGrowsWithThickness() throws {
        let slider = NSSlider(frame: NSRect(x: 0, y: 0, width: 22, height: 100))
        let cell = WedgeSliderCell()
        slider.cell = cell
        slider.minValue = 0
        slider.maxValue = 1
        slider.isVertical = true
        cell.tool = .arrow
        cell.range = Tool.strokeRange

        slider.doubleValue = 1 - ThicknessScale.position(of: 2, in: Tool.strokeRange)
        let small = cell.knobRect(flipped: true)
        slider.doubleValue = 1 - ThicknessScale.position(of: 16, in: Tool.strokeRange)
        let large = cell.knobRect(flipped: true)
        #expect(cell.thickness == 16)
        #expect(small.width == WedgeSliderCell.minKnob)
        #expect(large.width == 16)
        #expect(large.midY > small.midY)
        #expect(large.midX == small.midX)

        slider.doubleValue = 0
        #expect(cell.knobRect(flipped: true).width == 22)
        #expect(cell.knobRect(flipped: true).maxY <= 100)
    }

    @Test func keyEventsDriveToolbar() throws {
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 800, height: 600), scale: 1), title: "Test",
            toolSettings: ToolSettings(preferences: Preferences(store: store)))
        defer { controller.close() }
        let window = try #require(controller.window)
        let toolbar = controller.toolbar
        window.makeFirstResponder(controller.canvasView)

        func press(_ characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) throws {
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode))
            window.sendEvent(event)
        }

        try press("l", keyCode: 37)
        #expect(toolbar.activeTool == .line)
        try press("O", keyCode: 31)
        #expect(toolbar.activeTool == .ellipse)

        try press("1", keyCode: 18)
        #expect(toolbar.currentStyle.color == Palette.colors[0])
        #expect(toolbar.settings.style(for: .line).color == Palette.defaultColor)

        try press("]", keyCode: 30)
        let thicker = toolbar.currentStyle.thickness
        #expect(thicker > Tool.strokeDefault)
        try press("[", keyCode: 33)
        try press("[", keyCode: 33)
        #expect(toolbar.currentStyle.thickness < Tool.strokeDefault)

        try press("t", keyCode: 17, modifiers: .command)
        #expect(toolbar.activeTool == .ellipse)

        try press("x", keyCode: 7)
        #expect(toolbar.activeTool == .pixelate)
        try press("2", keyCode: 19)
        #expect(toolbar.settings.style(for: .pixelate).color == Palette.defaultColor)

        try press("c", keyCode: 8)
        try press("]", keyCode: 30)
        #expect(toolbar.activeTool == .crop)
        #expect(toolbar.settings.style(for: .crop) == ToolStyle.defaultStyle(for: .crop))
    }
}
