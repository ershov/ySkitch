import Foundation

public enum DragTempFiles {
    public static var defaultRoot: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ySkitch-drag", isDirectory: true)
    }

    /// Per-drag subdirectory. Files are only removed on launch and quit because
    /// receivers may read them asynchronously after the drag ends.
    public static func makeDirectory(root: URL = defaultRoot) throws -> URL {
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func removeAll(root: URL = defaultRoot) {
        try? FileManager.default.removeItem(at: root)
    }
}
