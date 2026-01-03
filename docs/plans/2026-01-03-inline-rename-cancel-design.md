# Inline Rename Cancel-on-Blur Design

## Goals
- Cancel inline rename when focus leaves the rename field (click anywhere else).
- Cancel inline rename when selecting a different document.
- Keep Enter to commit and Escape to cancel.
- Keep double-click to enter rename for saved files.

## Behavior Summary
Inline rename is single-active: only one row can be edited at a time. When the rename field loses focus, the edit is canceled and the original name remains. Clicking another document cancels any active rename before switching selection. The rename only commits on Enter; it never commits on blur.

## State Management
Move rename state from per-row storage to a shared coordinator in the sidebar. The coordinator tracks:
- `editingDocumentID`
- `draftName`

It exposes operations:
- `beginEditing(id:currentName:)`
- `commit(for:)` -> `String?` (trimmed, nil if empty)
- `cancel()`
- `handleSelectionChange(to:)` (cancel if selection changes)
- `handleFocusChange(isFocused:)` (cancel on blur)

## UI Flow
- Double-click on a saved document name enters rename mode and focuses the text field.
- Press Enter commits and calls `AppState.renameDocument`.
- Press Escape cancels.
- Clicking anywhere else cancels (focus loss).
- Clicking another row cancels before selection change.

## Testing
Add unit tests for the coordinator:
- begin sets ID + draft
- commit trims and clears state
- commit returns nil for empty draft
- cancel clears state
- selection change cancels when switching documents
- focus loss cancels

UI remains a thin wrapper over the coordinator, so behavior is tested without UI automation.
