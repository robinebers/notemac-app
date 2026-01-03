import Foundation

enum TextStatisticsFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()

    static func format(counts: TextCounts) -> String {
        let charText = formatter.string(from: NSNumber(value: counts.characters)) ?? String(counts.characters)
        let wordText = formatter.string(from: NSNumber(value: counts.words)) ?? String(counts.words)
        return "\(charText) chars / \(wordText) words"
    }
}
