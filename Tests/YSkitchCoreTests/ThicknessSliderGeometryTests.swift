import CoreGraphics
import Testing
import YSkitchCore

@Suite struct ThicknessSliderGeometryTests {
    private let track = CGRect(x: 0, y: 0, width: 54, height: 158)

    @Test func travelEnds() {
        let stroke = ThicknessSliderGeometry(track: track, range: 1...40)
        #expect(stroke.top == 20)
        #expect(stroke.bottom == 157.5)
        #expect(stroke.y(at: 0) == stroke.bottom)
        #expect(stroke.y(at: 1) == stroke.top)

        let text = ThicknessSliderGeometry(track: track, range: 10...120)
        #expect(text.top == 27)
        #expect(text.bottom == 153)
    }

    @Test func positionRoundTrips() {
        let geometry = ThicknessSliderGeometry(track: track, range: 4...60)
        for position in [0, 0.25, 0.5, 1] {
            #expect(abs(geometry.position(atY: geometry.y(at: position)) - position) < 1e-9)
        }
        #expect(geometry.position(atY: -100) == 1)
        #expect(geometry.position(atY: 1000) == 0)
    }

    @Test func wedgeWidthIsValue() {
        for range in [1...40, 4...60, 10...120, 2...40] as [ClosedRange<CGFloat>] {
            let geometry = ThicknessSliderGeometry(track: track, range: range)
            for step in 0...20 {
                let t = Double(step) / 20
                let value = ThicknessScale.exactValue(at: t, in: range)
                #expect(abs(geometry.halfWidth(at: t) * 2 - min(value, track.width)) < 1e-9)
            }
        }
    }

    @Test func wedgeSpansTravel() {
        let geometry = ThicknessSliderGeometry(track: track, range: 10...120)
        let box = geometry.wedge().boundingBoxOfPath
        #expect(abs(box.minY - geometry.top) < 1e-9)
        #expect(abs(box.maxY - geometry.bottom) < 1e-9)
        #expect(abs(box.width - track.width) < 1e-9)
        #expect(abs(box.midX - track.midX) < 1e-9)
    }

    @Test func sampleRect() {
        let geometry = ThicknessSliderGeometry(track: track, range: 1...40)
        let min = geometry.sampleRect(value: 1, at: 0)
        #expect(min == CGRect(x: 26.5, y: 157, width: 1, height: 1))
        #expect(min.maxY == track.maxY)
        let max = geometry.sampleRect(value: 40, at: 1)
        #expect(max == CGRect(x: 7, y: 0, width: 40, height: 40))
    }

    @Test func exactValueIsUnrounded() {
        let value = ThicknessScale.exactValue(at: 0.3, in: 1...40)
        #expect(value != ThicknessScale.value(at: 0.3, in: 1...40))
        #expect(abs(value - pow(40, 0.3)) < 1e-9)
    }
}
