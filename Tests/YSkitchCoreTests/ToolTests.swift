import CoreGraphics
import Foundation
import Testing
@testable import YSkitchCore

@Suite struct ToolTests {
    @Test func keysMatchListAndAreUnique() {
        let keys = Tool.allCases.map(\.key)
        #expect(String(keys) == "VTALRUOPHXC")
        #expect(Set(keys).count == keys.count)
    }

    @Test func groupsCoverAllToolsInOrder() {
        #expect(Tool.groups.flatMap { $0 } == Tool.allCases)
        #expect(Tool.groups.map(\.count) == [1, 1, 5, 2, 1, 1])
    }

    @Test func colorUsage() {
        #expect(Tool.allCases.filter { !$0.usesColor } == [.select, .pixelate, .crop])
    }

    @Test func rangesAndDefaults() {
        for tool in [Tool.arrow, .line, .rectangle, .roundedRectangle, .ellipse, .pen] {
            #expect(tool.thicknessRange == 1...40)
            #expect(tool.defaultThickness == 4)
        }
        #expect(Tool.highlighter.thicknessRange == 4...60)
        #expect(Tool.highlighter.defaultThickness == 20)
        #expect(Tool.text.thicknessRange == 10...120)
        #expect(Tool.text.defaultThickness == 24)
        #expect(Tool.pixelate.thicknessRange == 2...40)
        #expect(Tool.pixelate.defaultThickness == 10)
        for tool in [Tool.select, .crop] {
            #expect(tool.thicknessRange == nil)
            #expect(tool.defaultThickness == nil)
        }
        for tool in Tool.allCases {
            if let range = tool.thicknessRange, let value = tool.defaultThickness {
                #expect(range.contains(value))
            }
        }
    }

    @Test func paletteOrderAndDefault() {
        let hex = Palette.colors.map { color in
            String(format: "%02X%02X%02X",
                   Int((color.red * 255).rounded()), Int((color.green * 255).rounded()), Int((color.blue * 255).rounded()))
        }
        #expect(hex == ["FF2500", "FF941A", "FEF500", "00E700", "198EFE", "FF2E6C", "FFFFFF", "000000"])
        #expect(Palette.defaultColor == RGBAColor(hex: 0xFF2E6C))
        #expect(Palette.colors[5] == Palette.defaultColor)
        #expect(Palette.names == ["Red", "Orange", "Yellow", "Green", "Blue", "Pink", "White", "Black"])
    }
}

@Suite struct ThicknessScaleTests {
    private let range: ClosedRange<CGFloat> = 1...40

    @Test func endpoints() {
        #expect(ThicknessScale.position(of: 1, in: range) == 0)
        #expect(ThicknessScale.position(of: 40, in: range) == 1)
        #expect(ThicknessScale.value(at: 0, in: range) == 1)
        #expect(ThicknessScale.value(at: 1, in: range) == 40)
    }

    @Test func logarithmicMidpoint() {
        let mid = ThicknessScale.value(at: 0.5, in: 4...64)
        #expect(mid == 16)
    }

    @Test func roundTrip() {
        for range in [range, 4...60, 10...120, 2...40] as [ClosedRange<CGFloat>] {
            var value = range.lowerBound
            while value <= range.upperBound {
                let position = ThicknessScale.position(of: value, in: range)
                #expect(ThicknessScale.value(at: position, in: range) == value)
                value += 0.5
            }
        }
    }

    @Test func roundsToHalfPoint() {
        for step in 0...100 {
            let value = ThicknessScale.value(at: Double(step) / 100, in: range)
            #expect((value * 2).rounded() == value * 2)
        }
    }

    @Test func clamps() {
        #expect(ThicknessScale.position(of: 0.2, in: range) == 0)
        #expect(ThicknessScale.position(of: 100, in: range) == 1)
        #expect(ThicknessScale.value(at: -1, in: range) == 1)
        #expect(ThicknessScale.value(at: 2, in: range) == 40)
        #expect(ThicknessScale.stepped(40, in: range, by: 1) == 40)
        #expect(ThicknessScale.stepped(1, in: range, by: -1) == 1)
        #expect(ThicknessScale.stepped(4, in: range, by: 100) == 40)
    }

    @Test func twentyStepsSpanRange() {
        for range in [range, 4...60, 10...120, 2...40] as [ClosedRange<CGFloat>] {
            #expect(ThicknessScale.stepped(range.lowerBound, in: range, by: 20) == range.upperBound)
            #expect(ThicknessScale.stepped(range.upperBound, in: range, by: -20) == range.lowerBound)
        }
    }

    @Test func everyStepChangesValue() {
        var value: CGFloat = 1
        while value < 40 {
            let next = ThicknessScale.stepped(value, in: range, by: 1)
            #expect(next > value)
            #expect(ThicknessScale.stepped(next, in: range, by: -1) < next)
            value = next
        }
    }

    @Test func stepIsOneTwentiethOfRange() {
        let up = ThicknessScale.stepped(20, in: 10...120, by: 1)
        let expected = ThicknessScale.value(
            at: ThicknessScale.position(of: 20, in: 10...120) + 0.05, in: 10...120)
        #expect(abs(up - expected) <= 0.5)
    }
}

@Suite struct ToolStylesTests {
    @Test func defaults() {
        let styles = ToolStyles()
        #expect(styles[.arrow] == ToolStyle(color: Palette.defaultColor, thickness: 4))
        #expect(styles[.text] == ToolStyle(color: Palette.defaultColor, thickness: 24))
        #expect(styles[.select] == ToolStyle(color: Palette.defaultColor, thickness: 1))
    }

    @Test func setAndGetArePerTool() {
        var styles = ToolStyles()
        styles[.arrow].color = Palette.colors[0]
        styles[.line].thickness = 10
        #expect(styles[.arrow] == ToolStyle(color: Palette.colors[0], thickness: 4))
        #expect(styles[.line] == ToolStyle(color: Palette.defaultColor, thickness: 10))
        #expect(styles[.pen] == ToolStyle.defaultStyle(for: .pen))
    }

    @Test func codableRoundTripKeyedByRawValue() throws {
        var styles = ToolStyles()
        styles[.roundedRectangle] = ToolStyle(color: Palette.colors[4], thickness: 12.5)
        styles[.text].thickness = 48
        let data = try JSONEncoder().encode(styles)
        #expect(try JSONDecoder().decode(ToolStyles.self, from: data) == styles)

        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["roundedRectangle", "text"])
    }

    @Test func decodingIgnoresUnknownTools() throws {
        let json = #"{"arrow":{"color":{"red":0,"green":0,"blue":0,"alpha":1},"thickness":7},"lasso":{"color":{"red":1,"green":1,"blue":1,"alpha":1},"thickness":3}}"#
        let styles = try JSONDecoder().decode(ToolStyles.self, from: Data(json.utf8))
        #expect(styles[.arrow] == ToolStyle(color: RGBAColor(hex: 0x000000), thickness: 7))
    }
}

@Suite struct ToolShortcutTests {
    @Test func lettersBothCases() {
        for tool in Tool.allCases {
            #expect(ToolShortcut.action(for: String(tool.key)) == .tool(tool))
            #expect(ToolShortcut.action(for: tool.key.lowercased()) == .tool(tool))
        }
    }

    @Test func digits() {
        for digit in 1...8 {
            #expect(ToolShortcut.action(for: "\(digit)") == .color(digit - 1))
        }
        #expect(ToolShortcut.action(for: "0") == nil)
        #expect(ToolShortcut.action(for: "9") == nil)
    }

    @Test func brackets() {
        #expect(ToolShortcut.action(for: "[") == .thicknessStep(-1))
        #expect(ToolShortcut.action(for: "]") == .thicknessStep(1))
    }

    @Test func keysRoundTrip() {
        let actions = Tool.allCases.map { ToolShortcut.Action.tool($0) }
            + Palette.colors.indices.map { .color($0) } + [.thicknessStep(-1), .thicknessStep(1)]
        for action in actions {
            let key = ToolShortcut.key(for: action)
            #expect(key == key.lowercased())
            #expect(ToolShortcut.action(for: key) == action)
        }
        #expect(ToolShortcut.key(for: .tool(.roundedRectangle)) == "u")
        #expect(ToolShortcut.key(for: .color(0)) == "1")
    }

    @Test func unknown() {
        for characters in ["", "q", "Z", " ", "{", "ab", "١", "\u{1B}"] {
            #expect(ToolShortcut.action(for: characters) == nil)
        }
    }
}
