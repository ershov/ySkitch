import Foundation

public enum DocumentNaming {
    public static func title(sourceURL: URL?, date: Date, timeZone: TimeZone = .current) -> String {
        if let sourceURL {
            return sourceURL.deletingPathExtension().lastPathComponent
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "ySkitch \(formatter.string(from: date))"
    }
}
