import Foundation
import Testing
@testable import NoteMac

@Suite("Text Statistics Formatter Tests")
struct TextStatisticsFormatterTests {
    @Test("Formats counts with character and word labels")
    func formatsCounts() {
        let counts = TextCounts(characters: 11, words: 2)
        let formatted = TextStatisticsFormatter.format(counts: counts)
        #expect(formatted == "\(formattedNumber(11)) chars / \(formattedNumber(2)) words")
    }

    @Test("Formats zero counts")
    func formatsZeroCounts() {
        let counts = TextCounts(characters: 0, words: 0)
        let formatted = TextStatisticsFormatter.format(counts: counts)
        #expect(formatted == "\(formattedNumber(0)) chars / \(formattedNumber(0)) words")
    }

    private func formattedNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
