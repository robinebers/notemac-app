import Foundation
import Testing
@testable import NoteMac

@Suite("Inline Rename Coordinator")
struct InlineRenameCoordinatorTests {
    @Test("Begin editing sets active id and draft")
    func beginEditingSetsDraft() {
        var coordinator = InlineRenameCoordinator()
        let id = UUID()

        coordinator.beginEditing(id: id, currentName: "Notes.md")

        #expect(coordinator.isEditing(id: id))
        #expect(coordinator.draftName == "Notes.md")
    }

    @Test("Commit trims and clears state")
    func commitTrimsAndClearsState() {
        var coordinator = InlineRenameCoordinator()
        let id = UUID()
        coordinator.beginEditing(id: id, currentName: "Old.md")
        coordinator.draftName = "  New  "

        let result = coordinator.commit(for: id)

        #expect(result == "New")
        #expect(coordinator.editingDocumentID == nil)
        #expect(coordinator.draftName.isEmpty)
    }

    @Test("Commit returns nil for empty draft")
    func commitEmptyReturnsNil() {
        var coordinator = InlineRenameCoordinator()
        let id = UUID()
        coordinator.beginEditing(id: id, currentName: "Old.md")
        coordinator.draftName = "   "

        let result = coordinator.commit(for: id)

        #expect(result == nil)
        #expect(coordinator.editingDocumentID == nil)
        #expect(coordinator.draftName.isEmpty)
    }

    @Test("Cancel clears state")
    func cancelClearsState() {
        var coordinator = InlineRenameCoordinator()
        let id = UUID()
        coordinator.beginEditing(id: id, currentName: "Old.md")

        coordinator.cancel()

        #expect(coordinator.editingDocumentID == nil)
        #expect(coordinator.draftName.isEmpty)
    }

    @Test("Selection change cancels when switching documents")
    func selectionChangeCancels() {
        var coordinator = InlineRenameCoordinator()
        let idA = UUID()
        let idB = UUID()
        coordinator.beginEditing(id: idA, currentName: "Old.md")

        coordinator.handleSelectionChange(to: idB)

        #expect(coordinator.editingDocumentID == nil)
        #expect(coordinator.draftName.isEmpty)
    }

    @Test("Selection change keeps edit when reselecting same document")
    func selectionChangeKeepsSameDoc() {
        var coordinator = InlineRenameCoordinator()
        let idA = UUID()
        coordinator.beginEditing(id: idA, currentName: "Old.md")

        coordinator.handleSelectionChange(to: idA)

        #expect(coordinator.editingDocumentID == idA)
    }

    @Test("Focus loss cancels edit")
    func focusLossCancelsEdit() {
        var coordinator = InlineRenameCoordinator()
        let idA = UUID()
        coordinator.beginEditing(id: idA, currentName: "Old.md")

        coordinator.handleFocusChange(id: idA, isFocused: false)

        #expect(coordinator.editingDocumentID == nil)
        #expect(coordinator.draftName.isEmpty)
    }

    @Test("Focus loss for another document does not cancel current edit")
    func focusLossDifferentDocumentKeepsEdit() {
        var coordinator = InlineRenameCoordinator()
        let idA = UUID()
        let idB = UUID()
        coordinator.beginEditing(id: idB, currentName: "New.md")

        coordinator.handleFocusChange(id: idA, isFocused: false)

        #expect(coordinator.editingDocumentID == idB)
    }
}
