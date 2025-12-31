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

    /// The last saved/loaded content snapshot for intelligent dirty comparison
    private var savedContent: String

    var content: String {
        didSet {
            if content != oldValue {
                lastModifiedAt = Date()
            }
        }
    }
    var filePath: URL?

    /// Computed: true when current content differs from saved snapshot
    var isModified: Bool {
        content != savedContent
    }

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
        self.savedContent = content  // Snapshot initial content
        self.content = content
        self.filePath = filePath
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.scrollPosition = scrollPosition
        self.createdAt = createdAt ?? Date()
        self.lastModifiedAt = lastModifiedAt ?? Date()
        self.encoding = encoding
        self.encodingName = encodingName
        self.lineEnding = lineEnding
    }

    /// Update the saved content snapshot (call after save/load)
    func markSaved() {
        savedContent = content
    }

    /// Mark as modified for recovered documents (file missing on restore)
    func markAsRecovered() {
        savedContent = "\0RECOVERED_DOCUMENT\0"
    }
}
