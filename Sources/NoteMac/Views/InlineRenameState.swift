import Foundation

struct InlineRenameState {
    private(set) var isEditing: Bool = false
    var draftName: String = ""

    mutating func beginEditing(with currentName: String) {
        isEditing = true
        draftName = currentName
    }

    mutating func commit() -> String? {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        isEditing = false
        draftName = ""
        return trimmed.isEmpty ? nil : trimmed
    }

    mutating func cancel() {
        isEditing = false
        draftName = ""
    }
}
