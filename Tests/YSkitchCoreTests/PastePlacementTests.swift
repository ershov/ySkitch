import CoreGraphics
import Testing
@testable import YSkitchCore

private func rectangle(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 20, _ h: CGFloat = 10) -> Annotation {
    Annotation(
        style: AnnotationStyle(color: RGBAColor(hex: 0xFF2500), thickness: 4),
        shape: .rectangle(CGRect(x: x, y: y, width: w, height: h)))
}

@Suite struct PastePlacementTests {
    let canvas = CGRect(x: 0, y: 0, width: 200, height: 200)

    private func place(
        _ pasted: [Annotation], at anchor: CGPoint, existing: [Annotation] = [], targets: [CGVector] = []
    ) -> (snapped: CGVector, final: CGVector) {
        PastePlacement.offset(
            for: pasted, anchor: anchor, canvas: canvas, existing: existing.map(\.shape), snapTargets: targets)
    }

    @Test func centersOnAnchor() {
        let item = rectangle(10, 10)
        let result = place([item], at: CGPoint(x: 120, y: 100))
        #expect(result.final == CGVector(dx: 100, dy: 85))
        #expect(item.translated(by: result.final).bounds.center == CGPoint(x: 120, y: 100))
    }

    @Test func centersUnionOfGroup() {
        let items = [rectangle(0, 0), rectangle(60, 0)]
        let result = place(items, at: CGPoint(x: 100, y: 100))
        #expect(result.final == CGVector(dx: 60, dy: 95))
    }

    @Test(arguments: [
        CGPoint(x: -50, y: 100), CGPoint(x: 400, y: 100), CGPoint(x: 100, y: -50), CGPoint(x: 100, y: 400),
        CGPoint(x: -50, y: -50), CGPoint(x: 400, y: 400),
    ])
    func clampsRenderBoundsInsideCanvas(anchor: CGPoint) {
        let item = rectangle(10, 10)
        let moved = item.translated(by: place([item], at: anchor).final)
        #expect(canvas.contains(moved.renderBounds))
    }

    @Test func oversizedGroupCentersOnCanvas() {
        let item = rectangle(0, 0, 300, 10)
        let moved = item.translated(by: place([item], at: CGPoint(x: 20, y: 100)).final)
        #expect(moved.renderBounds.midX == canvas.midX)
        #expect(moved.bounds.midY == 100)
    }

    @Test func nearOriginalSnapsAndCascades() {
        let item = rectangle(10, 10)
        let result = place([item], at: CGPoint(x: 25, y: 20), existing: [item])
        #expect(result.snapped == .zero)
        #expect(result.final == PastePlacement.step)
    }

    @Test func cascadesPastSeveralExistingCopies() {
        let item = rectangle(10, 10)
        let existing = [item, item.translated(by: PastePlacement.step)]
        let result = place([item], at: CGPoint(x: 20, y: 15), existing: existing)
        #expect(result.final == CGVector(dx: 20, dy: 20))
    }

    @Test func farFromOriginalLandsAtAnchor() {
        let item = rectangle(10, 10)
        let result = place([item], at: CGPoint(x: 150, y: 150), existing: [item])
        #expect(result.snapped == result.final)
        #expect(result.final == CGVector(dx: 130, dy: 135))
    }

    @Test func earlierPasteIsSnapTarget() {
        let item = rectangle(10, 10)
        let anchor = CGPoint(x: 150, y: 150)
        var targets: [CGVector] = []
        var existing = [item]
        var finals: [CGVector] = []
        for _ in 0..<3 {
            let result = place([item], at: anchor, existing: existing, targets: targets)
            targets.append(result.snapped)
            existing.append(item.translated(by: result.final))
            finals.append(result.final)
        }
        #expect(finals == [
            CGVector(dx: 130, dy: 135), CGVector(dx: 140, dy: 145), CGVector(dx: 150, dy: 155),
        ])
    }

    @Test func noSnapAtTenPoints() {
        let item = rectangle(10, 10)
        let target = CGVector(dx: 100, dy: 100)
        #expect(place([item], at: CGPoint(x: 120 + 10, y: 115), targets: [target]).snapped == CGVector(dx: 110, dy: 100))
        #expect(place([item], at: CGPoint(x: 120 + 9, y: 115), targets: [target]).snapped == target)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
