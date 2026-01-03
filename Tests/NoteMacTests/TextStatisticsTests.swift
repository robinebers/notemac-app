import Testing
@testable import NoteMac

@Suite("Text Statistics Tests")
struct TextStatisticsTests {
    @Test("Counts characters and words for basic text")
    func countsBasicText() {
        let counts = TextStatistics.counts(in: "Hello world")
        #expect(counts.characters == 11)
        #expect(counts.words == 2)
    }

    @Test("Counts empty string as zero")
    func countsEmptyText() {
        let counts = TextStatistics.counts(in: "")
        #expect(counts.characters == 0)
        #expect(counts.words == 0)
    }
}
