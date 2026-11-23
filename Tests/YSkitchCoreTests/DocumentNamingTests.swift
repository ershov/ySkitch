import Foundation
import Testing
@testable import YSkitchCore

struct DocumentNamingTests {
    @Test func titleFromFileURL() {
        let url = URL(fileURLWithPath: "/tmp/Screenshot 2026-11-24 at 10.15.32.png")
        #expect(DocumentNaming.title(sourceURL: url, date: .now) == "Screenshot 2026-11-24 at 10.15.32")
    }

    @Test func titleFromDate() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let date = Date(timeIntervalSince1970: 1_795_515_332)
        #expect(DocumentNaming.title(sourceURL: nil, date: date, timeZone: utc) == "ySkitch 2026-11-24 at 10.15.32")
        let plus3 = try #require(TimeZone(secondsFromGMT: 3 * 3600))
        #expect(DocumentNaming.title(sourceURL: nil, date: date, timeZone: plus3) == "ySkitch 2026-11-24 at 13.15.32")
    }
}
