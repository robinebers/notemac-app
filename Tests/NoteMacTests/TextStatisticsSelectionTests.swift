import Foundation
import Testing
@testable import NoteMac

@Suite("Text Statistics Selection Tests")
struct TextStatisticsSelectionTests {
    @Test("Counts selection when range is valid and non-empty")
    func countsSelection() {
        let text = "Hello world"
        let range = NSRange(location: 0, length: 5)
        let counts = TextStatistics.counts(in: text, selectionRange: range)
        #expect(counts.characters == 5)
        #expect(counts.words == 1)
    }

    @Test("Falls back to full text for empty selection")
    func fallsBackForEmptySelection() {
        let text = "Hello world"
        let range = NSRange(location: 0, length: 0)
        let counts = TextStatistics.counts(in: text, selectionRange: range)
        #expect(counts.characters == 11)
        #expect(counts.words == 2)
    }

    @Test("Falls back to full text for invalid range")
    func fallsBackForInvalidRange() {
        let text = "Hello world"
        let range = NSRange(location: 999, length: 5)
        let counts = TextStatistics.counts(in: text, selectionRange: range)
        #expect(counts.characters == 11)
        #expect(counts.words == 2)
    }
}
