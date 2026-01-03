# Inline Rename + Default .md Save Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Default Save As to `.md` when no extension is provided, and allow inline rename of already saved files that renames on disk and updates the sidebar.

**Architecture:** Add small filename/URL helpers in `AppState` to normalize markdown defaults. Implement `renameDocument(id:to:)` in `AppState` to perform file moves and update `filePath`. Update Save As flows to use the helpers, and update `SidebarRow` to inline-edit the title and call the rename method.

**Tech Stack:** Swift, SwiftUI, Foundation, Swift Testing (`Testing`)

### Task 1: Filename normalization helpers

**Files:**
- Modify: `Sources/NoteMac/Models/AppState.swift`
- Test: `Tests/NoteMacTests/AppStateTests.swift`

**Step 1: Write the failing tests**

Add to `Tests/NoteMacTests/AppStateTests.swift`:

```swift
    @Test("Default markdown filename appends .md when missing")
    func defaultMarkdownFilenameAddsMd() {
        #expect(AppState.defaultMarkdownFilename("Notes") == "Notes.md")
    }

    @Test("Default markdown filename keeps existing extension")
    func defaultMarkdownFilenameKeepsExtension() {
        #expect(AppState.defaultMarkdownFilename("Notes.txt") == "Notes.txt")
    }

    @Test("Default markdown filename trims whitespace")
    func defaultMarkdownFilenameTrimsWhitespace() {
        #expect(AppState.defaultMarkdownFilename("  Notes  ") == "Notes.md")
    }

    @Test("URL helper appends .md when missing")
    func urlHelperAppendsMarkdownExtension() {
        let url = URL(fileURLWithPath: "/tmp/Notes")
        #expect(AppState.urlByAppendingMarkdownExtensionIfNeeded(url).pathExtension == "md")
    }
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppStateTests`

Expected: FAIL with errors like “type ‘AppState’ has no member ‘defaultMarkdownFilename’”.

**Step 3: Write minimal implementation**

Add to `Sources/NoteMac/Models/AppState.swift` (as `internal` static helpers):

```swift
    static func defaultMarkdownFilename(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled.md" }
        let url = URL(fileURLWithPath: trimmed)
        if url.pathExtension.isEmpty {
            return trimmed + ".md"
        }
        return trimmed
    }

    static func urlByAppendingMarkdownExtensionIfNeeded(_ url: URL) -> URL {
        if url.pathExtension.isEmpty {
            return url.appendingPathExtension("md")
        }
        return url
    }
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter AppStateTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/NoteMacTests/AppStateTests.swift Sources/NoteMac/Models/AppState.swift
git commit -m "test: add filename helpers for markdown defaults"
```

### Task 2: Rename saved file on disk via AppState

**Files:**
- Modify: `Sources/NoteMac/Models/AppState.swift`
- Test: `Tests/NoteMacTests/AppStateTests.swift`

**Step 1: Write the failing tests**

Add helper + tests in `Tests/NoteMacTests/AppStateTests.swift`:

```swift
    func withTempDirectory(_ test: (URL) throws -> Void) throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }
        try test(tempDirectory)
    }

    @Test("Rename saved document updates file and path")
    @MainActor
    func renameSavedDocumentUpdatesFile() throws {
        try withTempDirectory { tempDirectory in
            let originalURL = tempDirectory.appendingPathComponent("Old.md")
            try "Hello".write(to: originalURL, atomically: true, encoding: .utf8)

            let doc = Document(content: "Hello", filePath: originalURL)
            doc.markSaved()
            let state = AppState()
            state.documents = [doc]
            state.activeDocumentID = doc.id

            state.renameDocument(id: doc.id, to: "New")

            let newURL = tempDirectory.appendingPathComponent("New.md")
            #expect(FileManager.default.fileExists(atPath: newURL.path))
            #expect(!FileManager.default.fileExists(atPath: originalURL.path))
            #expect(doc.filePath == newURL)
        }
    }

    @Test("Rename ignores empty names")
    @MainActor
    func renameIgnoresEmptyName() throws {
        try withTempDirectory { tempDirectory in
            let originalURL = tempDirectory.appendingPathComponent("Old.md")
            try "Hello".write(to: originalURL, atomically: true, encoding: .utf8)

            let doc = Document(content: "Hello", filePath: originalURL)
            doc.markSaved()
            let state = AppState()
            state.documents = [doc]
            state.activeDocumentID = doc.id

            state.renameDocument(id: doc.id, to: "   ")

            #expect(FileManager.default.fileExists(atPath: originalURL.path))
            #expect(doc.filePath == originalURL)
        }
    }
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter AppStateTests`

Expected: FAIL with errors like “type ‘AppState’ has no member ‘renameDocument’”.

**Step 3: Write minimal implementation**

Add to `Sources/NoteMac/Models/AppState.swift`:

```swift
    @MainActor
    func renameDocument(id: UUID, to proposedName: String) {
        guard let doc = documents.first(where: { $0.id == id }),
              let filePath = doc.filePath else { return }

        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let finalName = AppState.defaultMarkdownFilename(trimmed)
        let newURL = filePath.deletingLastPathComponent().appendingPathComponent(finalName)
        guard newURL != filePath else { return }

        do {
            try FileManager.default.moveItem(at: filePath, to: newURL)
            doc.filePath = newURL
        } catch {
            showError(message: "Failed to rename file: \(error.localizedDescription)")
        }
    }
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter AppStateTests`

Expected: PASS.

**Step 5: Commit**

```bash
git add Tests/NoteMacTests/AppStateTests.swift Sources/NoteMac/Models/AppState.swift
git commit -m "feat: add appstate rename for saved files"
```

### Task 3: Default Save As to `.md`

**Files:**
- Modify: `Sources/NoteMac/Models/AppState.swift`

**Step 1: Write the failing test**

No new automated test beyond Task 1 helpers. (Save panel is UI). Proceed with manual verification only.

**Step 2: Implement minimal code**

Update both Save As paths in `Sources/NoteMac/Models/AppState.swift`:
- `panel.nameFieldStringValue = AppState.defaultMarkdownFilename(doc.title)`
- After `panel.url`, normalize with `AppState.urlByAppendingMarkdownExtensionIfNeeded(url)`
- Save to the normalized URL and set `doc.filePath = normalizedURL`

**Step 3: Manual check**

Run app and save an untitled document. Expected file name ends with `.md` when the user doesn’t type an extension.

**Step 4: Commit**

```bash
git add Sources/NoteMac/Models/AppState.swift
git commit -m "feat: default save-as to markdown extension"
```

### Task 4: Inline rename in sidebar

**Files:**
- Modify: `Sources/NoteMac/Views/Sidebar.swift`

**Step 1: Write the failing test**

No existing UI testing harness for SwiftUI. Request permission to proceed without an automated UI test; manual verification only.

**Step 2: Implement minimal code**

In `SidebarRow`:
- Add state for editing and the pending filename.
- Replace the title `Text` with a `TextField` when editing.
- Add a double-click gesture to enter edit mode for saved files only.
- On submit: call `onRename(pendingName)` and exit edit mode.
- On escape: cancel edit mode.

In `Sidebar`:
- Pass `onRename` that calls `appState.renameDocument(id:to:)`.

**Step 3: Manual check**

Run app, open a saved file, double-click its name, edit, press Enter. Expected: file renamed on disk and sidebar updates.

**Step 4: Commit**

```bash
git add Sources/NoteMac/Views/Sidebar.swift
git commit -m "feat: inline rename saved files"
```
