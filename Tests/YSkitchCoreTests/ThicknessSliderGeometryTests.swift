import CoreGraphics
import Testing
import YSkitchCore

@Suite struct ThicknessSliderGeometryTests {
    private let track = CGRect(x: 0, y: 0, width: 54, height: 174)

    @Test func paddingsDeriveFromAllRanges() {
        #expect(ThicknessSliderGeometry.topPadding(trackWidth: 54) == 27)
        #expect(ThicknessSliderGeometry.bottomPadding(trackWidth: 54) == 12)
        #expect(ThicknessSliderGeometry.bottomPadding(trackWidth: 54) >= ThicknessSliderGeometry.minimumPadding)
        #expect(ThicknessSliderGeometry.topPadding(trackWidth: 100) == 50)
        #expect(ThicknessSliderGeometry.height(trackWidth: 54) == 174)
    }

    @Test func travelIsConstantForEveryTool() {
        for tool in Tool.allCases {
            guard let range = tool.thicknessRange else { continue }
            let geometry = ThicknessSliderGeometry(track: track, range: range)
            #expect(geometry.top == 27)
            #expect(geometry.bottom - geometry.top == ThicknessSliderGeometry.travel)
            #expect(ThicknessSliderGeometry.travel == 135)
            #expect(geometry.bottom + ThicknessSliderGeometry.bottomPadding(trackWidth: 54) == track.maxY)
        }
    }

    @Test func samePositionSameYAcrossTools() {
        let ys = Tool.allCases.compactMap(\.thicknessRange).map {
            ThicknessSliderGeometry(track: track, range: $0)
        }
        for position in [0, 0.3, 0.5, 1] {
            #expect(Set(ys.map { $0.y(at: position) }).count == 1)
        }
    }

    @Test func endsClamp() {
        let geometry = ThicknessSliderGeometry(track: track, range: 1...40)
        #expect(geometry.y(at: 0) == geometry.bottom)
        #expect(geometry.y(at: 1) == geometry.top)
        #expect(geometry.position(atY: 0) == 1)
        #expect(geometry.position(atY: track.maxY) == 0)
        #expect(geometry.position(atY: geometry.top - 1) == 1)
        #expect(geometry.position(atY: geometry.bottom + 1) == 0)
    }

    @Test func paddingsAreClickable() {
        let geometry = ThicknessSliderGeometry(track: track, range: 1...40)
        let bottomPadding = ThicknessSliderGeometry.bottomPadding(trackWidth: track.width)
        for offset in stride(from: 0, through: bottomPadding, by: 1) {
            #expect(geometry.position(atY: geometry.bottom + offset) == 0)
        }
        for offset in stride(from: 0, through: geometry.top - track.minY, by: 1) {
            #expect(geometry.position(atY: geometry.top - offset) == 1)
        }
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
        #expect(min == CGRect(x: 26.5, y: 161.5, width: 1, height: 1))
        let max = geometry.sampleRect(value: 40, at: 1)
        #expect(max == CGRect(x: 7, y: 7, width: 40, height: 40))
    }

    @Test func exactValueIsUnrounded() {
        let value = ThicknessScale.exactValue(at: 0.3, in: 1...40)
        #expect(value != ThicknessScale.value(at: 0.3, in: 1...40))
        #expect(abs(value - pow(40, 0.3)) < 1e-9)
    }
}
