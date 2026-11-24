import AppKit
import CoreText
import SwiftUI
import YSkitchCore

struct ToolbarView: View {
    static let width: CGFloat = 140
    static let rowHeight: CGFloat = 36
    static let groupGap: CGFloat = 14
    static let padding: CGFloat = 10
    static let toolButtonWidth: CGFloat = 48
    static let columnGap: CGFloat = 18
    static let colorColumnWidth: CGFloat = 54
    static let swatchFrame: CGFloat = 33

    static var toolsColumnHeight: CGFloat {
        let rows = Tool.groups.reduce(0) { $0 + $1.count }
        return CGFloat(rows) * rowHeight + CGFloat(Tool.groups.count - 1) * groupGap
    }

    let model: ToolbarModel

    var body: some View {
        HStack(alignment: .top, spacing: Self.columnGap) {
            toolsColumn
            colorsColumn.frame(width: Self.colorColumnWidth, height: Self.toolsColumnHeight, alignment: .top)
        }
        .padding(.horizontal, Self.padding)
        .padding(.top, Self.padding)
        .frame(width: Self.width, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 1)
        }
    }

    private var toolsColumn: some View {
        VStack(spacing: Self.groupGap) {
            ForEach(Tool.groups, id: \.self) { group in
                VStack(spacing: 0) {
                    ForEach(group, id: \.self) { ToolButton(tool: $0, model: model) }
                }
            }
        }
    }

    private var colorsColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            swatches
            thicknessControl.frame(width: Self.colorColumnWidth)
        }
    }

    private var swatches: some View {
        let tool = model.styleTool
        let current = model.displayedStyle.color
        return VStack(spacing: 0) {
            ForEach(Palette.colors.indices, id: \.self) { index in
                SwatchButton(index: index, isSelected: tool.usesColor && Palette.colors[index] == current) {
                    model.selectColor(index: index)
                }
            }
        }
        .disabled(!tool.usesColor)
        .opacity(tool.usesColor ? 1 : 0.35)
    }

    private var thicknessControl: some View {
        let tool = model.styleTool
        let range = tool.thicknessRange ?? Tool.strokeRange
        return VStack(spacing: 2) {
            KeyLabel(text: "[")
            ThicknessSlider(
                tool: tool, style: model.displayedStyle, range: range,
                onDragBegin: { model.beginThicknessDrag() }, onDragEnd: { model.endThicknessDrag() }
            ) { model.setThickness($0) }
                .frame(maxHeight: .infinity)
                .help("Size")
            KeyLabel(text: "]")
        }
        .disabled(tool.thicknessRange == nil)
        .opacity(tool.thicknessRange == nil ? 0 : 1)
    }
}

private struct KeyLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}

private struct ToolIconView: View {
    let tool: Tool

    var body: some View {
        switch ToolIcon.icon(for: tool) {
        case .symbol(let name):
            Image(systemName: name).font(.system(size: 21))
        case .path(let path):
            Path(path).stroke(
                style: StrokeStyle(
                    lineWidth: ToolIcon.stroke, lineCap: .round,
                    lineJoin: ToolIcon.lineJoin(for: tool)))
        case .text:
            let font = TextStyle.font(size: 17)
            // Line box is centered by layout; shift so the cap height is centered instead.
            let shift = (CTFontGetAscent(font) + CTFontGetDescent(font)) / 2
                - (CTFontGetAscent(font) - CTFontGetCapHeight(font) / 2)
            Text("Aa").font(Font(font)).offset(y: shift)
        }
    }
}

private struct ToolButton: View {
    let tool: Tool
    let model: ToolbarModel

    var body: some View {
        let isActive = model.activeTool == tool
        Button { model.activeTool = tool } label: {
            HStack(spacing: 2) {
                KeyLabel(text: String(tool.key))
                ToolIconView(tool: tool)
                    .frame(width: ToolIcon.boxSize.width, height: ToolIcon.boxSize.height)
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            }
            .frame(width: ToolbarView.toolButtonWidth, height: ToolbarView.rowHeight)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isActive ? Color.accentColor.opacity(0.2) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("\(tool.name) (\(String(tool.key)))")
    }
}

private struct SwatchButton: View {
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                KeyLabel(text: "\(index + 1)")
                ZStack {
                    Circle().strokeBorder(Color.primary, lineWidth: 1.5).opacity(isSelected ? 1 : 0)
                    Circle().fill(Palette.colors[index].swiftUIColor)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                        .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 0.5))
                        .frame(width: 27, height: 27)
                }
                .frame(width: ToolbarView.swatchFrame, height: ToolbarView.swatchFrame)
            }
            .frame(width: ToolbarView.colorColumnWidth, height: ToolbarView.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Color \(index + 1)")
    }
}

/// Never becomes first responder, so key presses keep reaching the canvas.
final class ToolbarHostingView: NSHostingView<ToolbarView> {
    override var acceptsFirstResponder: Bool { false }
}

extension RGBAColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
