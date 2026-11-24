import AppKit
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
    static let swatchDiameter: CGFloat = 27
    static let keySpacing: CGFloat = 1
    static let sliderSpacing: CGFloat = 20
    static let dimmedOpacity: CGFloat = 0.35

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
        VStack(alignment: .leading, spacing: Self.sliderSpacing) {
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
        .opacity(tool.usesColor ? 1 : Self.dimmedOpacity)
    }

    private var thicknessControl: some View {
        let tool = model.styleTool
        let range = tool.thicknessRange ?? Tool.strokeRange
        return ThicknessSlider(
            tool: tool, style: model.displayedStyle, range: range,
            onDragBegin: { model.beginThicknessDrag() }, onDragEnd: { model.endThicknessDrag() }
        ) { model.setThickness($0) }
            .frame(maxHeight: .infinity)
            .help("Size")
            .disabled(tool.thicknessRange == nil)
            .opacity(tool.thicknessRange == nil ? Self.dimmedOpacity : 1)
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

    /// Sized to the visible glyph so the key label's baseline lands on its bottom edge.
    var body: some View {
        Group {
            switch ToolIcon.icon(for: tool) {
            case .symbol(let name):
                Image(systemName: name).font(.system(size: 21))
            case .path(let path):
                let bounds = path.copy(
                    strokingWithWidth: ToolIcon.stroke, lineCap: .round,
                    lineJoin: ToolIcon.lineJoin(for: tool), miterLimit: 10
                ).boundingBoxOfPath
                Path(path.copy(using: [CGAffineTransform(translationX: 0, y: -bounds.minY)]) ?? path)
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: ToolIcon.stroke, lineCap: .round,
                            lineJoin: ToolIcon.lineJoin(for: tool)))
                    .frame(height: bounds.height)
            case .text:
                Text("Aa").font(Font(TextStyle.font(size: 17)))
            }
        }
        .frame(width: ToolIcon.boxSize.width)
    }
}

private struct ToolButton: View {
    let tool: Tool
    let model: ToolbarModel

    var body: some View {
        let isActive = model.activeTool == tool
        Button { model.activeTool = tool } label: {
            HStack(alignment: .lastTextBaseline, spacing: ToolbarView.keySpacing) {
                ToolIconView(tool: tool)
                    .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                KeyLabel(text: String(tool.key))
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
            HStack(alignment: .lastTextBaseline, spacing: ToolbarView.keySpacing) {
                ZStack {
                    Circle().strokeBorder(Color.primary, lineWidth: 1.5).opacity(isSelected ? 1 : 0)
                    Circle().fill(Palette.colors[index].swiftUIColor)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                        .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 0.5))
                        .frame(width: ToolbarView.swatchDiameter, height: ToolbarView.swatchDiameter)
                }
                .frame(width: ToolbarView.swatchFrame, height: ToolbarView.swatchFrame)
                .alignmentGuide(.lastTextBaseline) { $0[.bottom] - (ToolbarView.swatchFrame - ToolbarView.swatchDiameter) / 2 }
                KeyLabel(text: "\(index + 1)")
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
