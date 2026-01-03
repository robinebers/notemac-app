# Inline Rename + Default Markdown Save Design

## Goals
- Default new saves to `.md` when the user doesn’t specify an extension.
- Allow inline rename on double-click for already saved files, renaming on disk and updating the sidebar title.
- Keep everything else unchanged (open/save panels, supported types, and file loading behavior).

## Default `.md` on Save
When showing Save As for an unsaved document, the filename field should default to a markdown name (e.g., `Untitled.md`). This keeps the Save panel’s UI intact while nudging the default extension to `.md`. After the user chooses a destination, if the selected URL has no extension, the app appends `.md` before writing. If the user explicitly types an extension (e.g., `.txt` or `.markdown`), the app preserves it.

Implementation detail: use a small helper to normalize a filename (trim whitespace, append `.md` when missing) and another helper to normalize URLs similarly. These helpers keep the behavior consistent across Save As flows (explicit save and “save before close”).

## Inline Rename
Sidebar rows for saved documents become inline-editable on double-click. The row swaps the label for a text field prefilled with the current filename. Enter commits the rename; Escape cancels. When committing, the app trims whitespace, appends `.md` if the name has no extension, and moves the file on disk within the same directory. On success, it updates `filePath` so the sidebar reflects the new name. If the rename fails (name conflict, permissions, etc.), it shows a simple error and keeps the old name.

## Error Handling
- Empty or whitespace-only rename: treat as cancel/no-op.
- Name collision or filesystem error: show an error and leave the file unchanged.

## Testing
Unit tests cover filename normalization and rename behavior via `AppState`, using temporary directories for file operations. UI-level editing isn’t directly tested; it delegates to `AppState` methods that are tested.
