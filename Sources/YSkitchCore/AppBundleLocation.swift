import Foundation

public enum AppBundleLocation {
    /// The `.app` containing `executable` (`X.app/Contents/MacOS/name`), following symlinks.
    public static func bundleURL(executable: URL) -> URL? {
        let resolved = realPath(executable)
        let macOS = resolved.deletingLastPathComponent()
        let contents = macOS.deletingLastPathComponent()
        let bundle = contents.deletingLastPathComponent()
        guard macOS.lastPathComponent == "MacOS", contents.lastPathComponent == "Contents",
              bundle.pathExtension == "app"
        else { return nil }
        return bundle
    }

    public static func realPath(_ url: URL) -> URL {
        guard let resolved = realpath(url.path(percentEncoded: false), nil) else { return url }
        defer { free(resolved) }
        return URL(filePath: String(cString: resolved))
    }

    public static var currentExecutable: URL? {
        var size: UInt32 = 0
        _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&buffer, &size) == 0 else { return nil }
        return URL(filePath: String(decoding: buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self))
    }
}
