import Foundation

struct TextCounts: Equatable {
    let characters: Int
    let words: Int
}

enum TextStatistics {
    static func counts(in text: String) -> TextCounts {
        let characters = text.count
        var words = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { _, _, _, _ in
            words += 1
        }
        return TextCounts(characters: characters, words: words)
    }
}
