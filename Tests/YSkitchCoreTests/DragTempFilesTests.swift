import Foundation
import Testing
@testable import YSkitchCore

struct DragTempFilesTests {
    private func uniqueRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ySkitch-test-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func removeAllDeletesDirectoryAndContents() throws {
        let root = uniqueRoot()
        let directory = try DragTempFiles.makeDirectory(root: root)
        try Data([1]).write(to: directory.appendingPathComponent("a.png"))
        DragTempFiles.removeAll(root: root)
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }

    @Test func removeAllWithMissingDirectoryIsNoOp() {
        DragTempFiles.removeAll(root: uniqueRoot())
    }

    @Test func makeDirectoryCreatesDistinctDirectories() throws {
        let root = uniqueRoot()
        defer { DragTempFiles.removeAll(root: root) }
        let a = try DragTempFiles.makeDirectory(root: root)
        let b = try DragTempFiles.makeDirectory(root: root)
        #expect(a != b)
        #expect(FileManager.default.fileExists(atPath: a.path))
    }
}
