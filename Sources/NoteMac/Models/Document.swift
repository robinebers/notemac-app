import Foundation
import Observation

enum LineEnding: String {
    case lf = "\n"
    case crlf = "\r\n"

    var displayName: String {
        switch self {
        case .lf: return "LF"
        case .crlf: return "CRLF"
        }
    }
}

@Observable
final class Document: Identifiable {
    let id: UUID
    var content: String {
        didSet {
            if content != oldValue {
                isModified = true
                lastModifiedAt = Date()
            }
        }
    }
    var filePath: URL?
    private(set) var isModified: Bool
    var cursorLine: Int
    var cursorColumn: Int
    var scrollPosition: CGFloat
    let createdAt: Date
    private(set) var lastModifiedAt: Date
    var encoding: String.Encoding
    var encodingName: String
    var lineEnding: LineEnding

    var title: String {
        filePath?.lastPathComponent ?? "Untitled"
    }

    var isMarkdown: Bool {
        guard let ext = filePath?.pathExtension.lowercased() else { return false }
        return ext == "md" || ext == "markdown"
    }

    init(
        id: UUID = UUID(),
        content: String = "",
        filePath: URL? = nil,
        encoding: String.Encoding = .utf8,
        encodingName: String = "UTF-8",
        lineEnding: LineEnding = .lf,
        cursorLine: Int = 1,
        cursorColumn: Int = 1,
        scrollPosition: CGFloat = 0,
        createdAt: Date? = nil,
        lastModifiedAt: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.filePath = filePath
        self.isModified = false
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.scrollPosition = scrollPosition
        self.createdAt = createdAt ?? Date()
        self.lastModifiedAt = lastModifiedAt ?? Date()
        self.encoding = encoding
        self.encodingName = encodingName
        self.lineEnding = lineEnding
    }

    func markSaved() {
        isModified = false
    }

    func markModified() {
        isModified = true
    }
}
