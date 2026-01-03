import Testing
@testable import NoteMac

@Suite("Inline Rename State")
struct InlineRenameStateTests {
    @Test("Begin editing sets draft name and editing state")
    func beginEditingSetsDraft() {
        var state = InlineRenameState()

        state.beginEditing(with: "Notes.md")

        #expect(state.isEditing)
        #expect(state.draftName == "Notes.md")
    }

    @Test("Commit trims whitespace and exits edit mode")
    func commitTrimsAndExits() {
        var state = InlineRenameState()
        state.beginEditing(with: "Old.md")
        state.draftName = "  New  "

        let result = state.commit()

        #expect(result == "New")
        #expect(!state.isEditing)
        #expect(state.draftName.isEmpty)
    }

    @Test("Commit returns nil for empty names")
    func commitEmptyReturnsNil() {
        var state = InlineRenameState()
        state.beginEditing(with: "Old.md")
        state.draftName = "   "

        let result = state.commit()

        #expect(result == nil)
        #expect(!state.isEditing)
        #expect(state.draftName.isEmpty)
    }

    @Test("Cancel exits edit mode and clears draft")
    func cancelClearsDraft() {
        var state = InlineRenameState()
        state.beginEditing(with: "Old.md")

        state.cancel()

        #expect(!state.isEditing)
        #expect(state.draftName.isEmpty)
    }
}
