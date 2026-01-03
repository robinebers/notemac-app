import Foundation
import Testing
@testable import NoteMac

@Suite("Text Statistics Formatter Tests")
struct TextStatisticsFormatterTests {
    @Test("Formats counts with character and word labels")
    func formatsCounts() {
        let counts = TextCounts(characters: 11, words: 2)
        let formatted = TextStatisticsFormatter.format(counts: counts)
        #expect(formatted == "11 chars / 2 words")
    }

    @Test("Formats zero counts")
    func formatsZeroCounts() {
        let counts = TextCounts(characters: 0, words: 0)
        let formatted = TextStatisticsFormatter.format(counts: counts)
        #expect(formatted == "0 chars / 0 words")
    }
}
