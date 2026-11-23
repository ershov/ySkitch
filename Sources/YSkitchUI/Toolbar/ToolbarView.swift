import AppKit
import SwiftUI
import YSkitchCore

struct ToolbarView: View {
    static let width: CGFloat = 144
    static let rowHeight: CGFloat = 22
    static let groupGap: CGFloat = 10
    static let previewSize: CGFloat = 36
    static let sliderHeight: CGFloat = 176

    let model: ToolbarModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            toolsColumn
            colorsColumn
            thicknessColumn
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
        let tool = model.activeTool
        let current = model.currentStyle.color
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

    private var thicknessColumn: some View {
        let tool = model.activeTool
        let style = model.currentStyle
        let range = tool.thicknessRange ?? Tool.strokeRange
        return VStack(spacing: 2) {
            KeyLabel(text: "[")
            ThicknessSlider(thickness: style.thickness, range: range) { model.setThickness($0) }
                .frame(width: 22, height: Self.sliderHeight)
                .help("Size")
            KeyLabel(text: "]")
            ThicknessPreview(tool: tool, style: style)
                .padding(.top, 8)
        }
        .frame(width: Self.previewSize)
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
            HStack(spacing: 4) {
                KeyLabel(text: "\(index + 1)").frame(width: 8)
                ZStack {
                    Circle().strokeBorder(Color.primary, lineWidth: 1.5).opacity(isSelected ? 1 : 0)
                    Circle().fill(Palette.colors[index].swiftUIColor)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 0.5))
                        .frame(width: 18, height: 18)
                }
                .frame(width: 22, height: 22)
            }
            .frame(height: ToolbarView.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Color \(index + 1)")
    }
}

private struct ThicknessPreview: View {
    let tool: Tool
    let style: ToolStyle

    var body: some View {
        let size = ToolbarView.previewSize
        Group {
            switch tool {
            case .text:
                Text("Aa")
                    .font(.system(size: style.thickness, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.05)
                    .foregroundStyle(style.color.swiftUIColor)
            case .pixelate:
                Mosaic(block: min(style.thickness, size / 2))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            default:
                let diameter = min(style.thickness, size)
                Circle()
                    .fill(style.color.swiftUIColor)
                    .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
                    .opacity(tool == .highlighter ? HighlighterStyle.opacity : 1)
                    .frame(width: diameter, height: diameter)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct Mosaic: View {
    let block: CGFloat

    var body: some View {
        Canvas { context, size in
            let shades: [Double] = [0.55, 0.75, 0.65, 0.85]
            let columns = Int((size.width / block).rounded(.up))
            let rows = Int((size.height / block).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns {
                    let rect = CGRect(x: CGFloat(column) * block, y: CGFloat(row) * block, width: block, height: block)
                    let shade = shades[(row * 3 + column * 2 + row * column) % shades.count]
                    context.fill(Path(rect), with: .color(white: shade))
                }
            }
        }
    }
}

/// Vertical; the top is the minimum so it lines up with the `[` (thinner) label.
private struct ThicknessSlider: NSViewRepresentable {
    let thickness: CGFloat
    let range: ClosedRange<CGFloat>
    let onChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: context.coordinator,
                              action: #selector(Coordinator.changed(_:)))
        slider.isVertical = true
        slider.isContinuous = true
        slider.refusesFirstResponder = true
        slider.controlSize = .small
        // The fill grows from the bottom (the maximum), which would read inverted.
        slider.trackFillColor = .clear
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.range = range
        context.coordinator.onChange = onChange
        // Leave the knob where the user dragged it when it already maps to the current value.
        if ThicknessScale.value(at: 1 - slider.doubleValue, in: range) != thickness {
            slider.doubleValue = 1 - ThicknessScale.position(of: thickness, in: range)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var range: ClosedRange<CGFloat> = Tool.strokeRange
        var onChange: (CGFloat) -> Void = { _ in }

        @objc func changed(_ sender: NSSlider) {
            onChange(ThicknessScale.value(at: 1 - sender.doubleValue, in: range))
        }
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
