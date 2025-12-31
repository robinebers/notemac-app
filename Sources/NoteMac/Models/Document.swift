import Foundation
import Observation

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
        filePath: URL? = nil
    ) {
        self.id = id
        self.content = content
        self.filePath = filePath
        self.isModified = false
        self.cursorLine = 1
        self.cursorColumn = 1
        self.scrollPosition = 0
        self.createdAt = Date()
        self.lastModifiedAt = Date()
    }

    func markSaved() {
        isModified = false
    }
}
