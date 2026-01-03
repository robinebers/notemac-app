import Foundation

struct InlineRenameCoordinator {
    private(set) var editingDocumentID: UUID?
    var draftName: String = ""

    mutating func beginEditing(id: UUID, currentName: String) {
        editingDocumentID = id
        draftName = currentName
    }

    func isEditing(id: UUID) -> Bool {
        editingDocumentID == id
    }

    mutating func commit(for id: UUID) -> String? {
        guard editingDocumentID == id else { return nil }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        editingDocumentID = nil
        draftName = ""
        return trimmed.isEmpty ? nil : trimmed
    }

    mutating func cancel() {
        editingDocumentID = nil
        draftName = ""
    }

    mutating func handleSelectionChange(to id: UUID?) {
        guard let editingDocumentID, editingDocumentID != id else { return }
        cancel()
    }

    mutating func handleFocusChange(isFocused: Bool) {
        if !isFocused {
            cancel()
        }
    }
}
