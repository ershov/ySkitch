import AppKit
import SwiftUI
import YSkitchCore

struct ToolbarView: View {
    static let width: CGFloat = 100
    static let rowHeight: CGFloat = 22
    static let groupGap: CGFloat = 10
    static let swatchKeyWidth: CGFloat = 8
    static let swatchSpacing: CGFloat = 4
    static let swatchSize: CGFloat = 22

    static var toolsColumnHeight: CGFloat {
        let rows = Tool.groups.reduce(0) { $0 + $1.count }
        return CGFloat(rows) * rowHeight + CGFloat(Tool.groups.count - 1) * groupGap
    }

    let model: ToolbarModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            toolsColumn
            colorsColumn.frame(height: Self.toolsColumnHeight, alignment: .top)
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
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
            thicknessControl
                .frame(width: Self.swatchSize)
                .padding(.leading, Self.swatchKeyWidth + Self.swatchSpacing)
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
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
    }
}

private struct ToolButton: View {
    let tool: Tool
    let model: ToolbarModel

    var body: some View {
        let isActive = model.activeTool == tool
        Button { model.activeTool = tool } label: {
            HStack(spacing: 2) {
                KeyLabel(text: String(tool.key)).frame(width: 10)
                Image(systemName: tool.symbolName)
                    .font(.system(size: 14))
                    .frame(width: 26)
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            }
            .frame(height: ToolbarView.rowHeight)
            .padding(.horizontal, 1)
            .background(
                RoundedRectangle(cornerRadius: 5)
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
            HStack(spacing: ToolbarView.swatchSpacing) {
                KeyLabel(text: "\(index + 1)").frame(width: ToolbarView.swatchKeyWidth)
                ZStack {
                    Circle().strokeBorder(Color.primary, lineWidth: 1.5).opacity(isSelected ? 1 : 0)
                    Circle().fill(Palette.colors[index].swiftUIColor)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 0.5))
                        .frame(width: 18, height: 18)
                }
                .frame(width: ToolbarView.swatchSize, height: ToolbarView.swatchSize)
            }
            .frame(height: ToolbarView.rowHeight)
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
