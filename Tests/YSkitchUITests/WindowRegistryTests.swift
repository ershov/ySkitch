import AppKit
import Testing
@testable import YSkitchUI

@MainActor
struct WindowRegistryTests {
    @Test func registersAndUnregistersWindows() throws {
        let registry = WindowRegistry()
        let first = registry.openNewDocument()
        let second = registry.openNewDocument()
        #expect(registry.controllers.count == 2)

        try #require(first.window).close()
        #expect(registry.controllers.count == 1)
        #expect(registry.controllers.first === second)

        try #require(second.window).close()
        #expect(registry.controllers.isEmpty)
    }
}
