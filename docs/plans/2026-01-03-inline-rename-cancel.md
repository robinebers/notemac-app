# Inline Rename Cancel-on-Blur Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Cancel inline rename when focus leaves the field or when another document is selected, while keeping Enter to commit and Escape to cancel.

**Architecture:** Introduce a shared rename coordinator in the sidebar to ensure only one row edits at a time. The coordinator handles begin/commit/cancel and cancels on selection or focus changes. Sidebar rows become thin UI wrappers that delegate to the coordinator.

**Tech Stack:** Swift, SwiftUI, Foundation, Swift Testing (`Testing`)

### Task 1: Add rename coordinator tests (TDD)

**Files:**
- Create: `Tests/NoteMacTests/InlineRenameCoordinatorTests.swift`

**Step 1: Write the failing tests**

```swift
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

        coordinator.handleFocusChange(isFocused: false)

        #expect(coordinator.editingDocumentID == nil)
        #expect(coordinator.draftName.isEmpty)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter InlineRenameCoordinatorTests`

Expected: FAIL with “cannot find 'InlineRenameCoordinator' in scope”.

**Step 3: Commit test**

```bash
git add Tests/NoteMacTests/InlineRenameCoordinatorTests.swift
git commit -m "test: cover inline rename coordinator"
```

### Task 2: Implement rename coordinator

**Files:**
- Create: `Sources/NoteMac/Views/InlineRenameCoordinator.swift`

**Step 1: Write minimal implementation**

```swift
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
```

**Step 2: Run tests to verify they pass**

Run: `swift test --filter InlineRenameCoordinatorTests`

Expected: PASS.

**Step 3: Commit**

```bash
git add Sources/NoteMac/Views/InlineRenameCoordinator.swift
git commit -m "feat: add inline rename coordinator"
```

### Task 3: Wire coordinator into sidebar

**Files:**
- Modify: `Sources/NoteMac/Views/Sidebar.swift`
- Remove: `Sources/NoteMac/Views/InlineRenameState.swift`
- Remove: `Tests/NoteMacTests/InlineRenameStateTests.swift`

**Step 1: Update sidebar to use coordinator**

- Replace per-row `InlineRenameState` with `@State var renameCoordinator` in `Sidebar`.
- Pass `isEditing` and `draftName` (binding) into the row.
- On double-click: `renameCoordinator.beginEditing(id: doc.id, currentName: doc.title)`.
- On submit: if `let name = renameCoordinator.commit(for: doc.id)` call `renameDocument`.
- On focus change in the row: `renameCoordinator.handleFocusChange(isFocused:)`.
- On selection change: call `renameCoordinator.handleSelectionChange(to: doc.id)` before setting active document.

**Step 2: Delete old state + tests**

Remove `InlineRenameState` and `InlineRenameStateTests` and update references.

**Step 3: Run full tests**

Run: `swift test`

Expected: PASS.

**Step 4: Commit**

```bash
git add Sources/NoteMac/Views/Sidebar.swift Sources/NoteMac/Views/InlineRenameCoordinator.swift Tests/NoteMacTests/InlineRenameCoordinatorTests.swift
git rm Sources/NoteMac/Views/InlineRenameState.swift Tests/NoteMacTests/InlineRenameStateTests.swift
git commit -m "feat: cancel inline rename on blur/selection"
```
