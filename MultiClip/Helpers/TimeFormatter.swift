import Foundation

@MainActor
enum TimeFormatter {
    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func relativeString(from date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: Date())
    }
}
