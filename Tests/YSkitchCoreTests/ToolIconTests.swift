import CoreGraphics
import Testing
@testable import YSkitchCore

@Suite struct ToolIconTests {
    private let codeDrawn: [Tool] = [.arrow, .line, .rectangle, .roundedRectangle, .ellipse]
    private let box = CGRect(origin: .zero, size: ToolIcon.boxSize)

    @Test func iconKinds() {
        for tool in Tool.allCases {
            switch ToolIcon.icon(for: tool) {
            case .path: #expect(codeDrawn.contains(tool), "\(tool)")
            case .text: #expect(tool == .text)
            case .symbol: #expect([.select, .pen, .highlighter, .pixelate, .crop].contains(tool), "\(tool)")
            }
        }
    }

    private func strokedBounds(_ tool: Tool) -> CGRect {
        let path = ToolIcon.centerlinePath(for: tool, in: box)
        let join: CGLineJoin = ToolIcon.lineJoin(for: tool)
        return path.copy(strokingWithWidth: ToolIcon.stroke, lineCap: .round, lineJoin: join, miterLimit: 10).boundingBoxOfPath
    }

    @Test func strokedIconsFitBox() {
        for tool in codeDrawn {
            let bounds = strokedBounds(tool)
            #expect(box.contains(bounds), "\(tool) \(bounds)")
        }
    }

    @Test func shapeOuterSizes() {
        let expected: [Tool: CGSize] = [
            .rectangle: CGSize(width: 22, height: 16),
            .roundedRectangle: CGSize(width: 19, height: 19),
            .ellipse: CGSize(width: 20, height: 20),
        ]
        for (tool, size) in expected {
            let bounds = strokedBounds(tool)
            #expect(abs(bounds.width - size.width) < 0.01 && abs(bounds.height - size.height) < 0.01, "\(tool) \(bounds)")
            #expect(abs(bounds.midX - box.midX) < 0.01 && abs(bounds.midY - box.midY) < 0.01, "\(tool)")
        }
    }

    @Test func lineRunsBottomLeftToTopRight() {
        let bounds = ToolIcon.centerlinePath(for: .line, in: box).boundingBoxOfPath
        #expect(bounds == CGRect(x: box.midX - 8, y: box.midY - 8, width: 16, height: 16))
    }
}
