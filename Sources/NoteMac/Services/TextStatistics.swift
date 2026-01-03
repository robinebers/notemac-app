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

    static func counts(in text: String, selectionRange: NSRange) -> TextCounts {
        guard selectionRange.length > 0,
              let range = Range(selectionRange, in: text) else {
            return counts(in: text)
        }
        return counts(in: String(text[range]))
    }
}
