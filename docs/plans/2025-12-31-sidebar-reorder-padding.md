# Sidebar Reorder + Padding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce horizontal padding in the sidebar file list and add drag-and-drop manual reordering that persists across restarts with new files appended at the bottom.

**Architecture:** The sidebar renders from `AppState.documents` in order. Reordering updates that array via a dedicated move method; persistence is automatic because `SessionStore` already serializes `documents` in array order. The UI adds drag reordering on the `List` and adjusts row insets/padding for tighter left/right spacing.

**Tech Stack:** SwiftUI (macOS), SwiftPM, Swift Testing

### Task 1: Add a move API in AppState and a failing test

**Files:**
- Modify: `Sources/NoteMac/Models/AppState.swift`
- Modify: `Tests/NoteMacTests/AppStateTests.swift`

**Step 1: Write the failing test**

```swift
@Test("Can reorder documents")
func canReorderDocuments() {
    let state = AppState()
    let docA = Document(content: "A")
    let docB = Document(content: "B")
    let docC = Document(content: "C")

    state.documents = [docA, docB, docC]

    // Move first document to the end
    state.moveDocuments(from: IndexSet(integer: 0), to: 3)

    #expect(state.documents.map { $0.id } == [docB.id, docC.id, docA.id])
}
```

**Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL with “value of type 'AppState' has no member 'moveDocuments'”

**Step 3: Write minimal implementation**

```swift
func moveDocuments(from source: IndexSet, to destination: Int) {
    documents.move(fromOffsets: source, toOffset: destination)
}
```

**Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/NoteMac/Models/AppState.swift Tests/NoteMacTests/AppStateTests.swift
git commit -m "feat: add document reorder api"
```

### Task 2: Wire drag-and-drop reordering in the sidebar list

**Files:**
- Modify: `Sources/NoteMac/Views/Sidebar.swift`

**Step 1: Write a focused test (UI behavior is manual)**

No automated UI test. Add a brief manual verification note in the PR/summary: drag a row to reorder; close/reopen app and order persists.

**Step 2: Implement List reordering**

Attach `.onMove` to the `ForEach` and keep the list in active edit mode so rows are draggable anywhere in the row:

```swift
List {
    ForEach(appState.documents) { doc in
        SidebarRow(...)
            .listRowInsets(...)
            .listRowSeparator(.hidden)
    }
    .onMove { indices, newOffset in
        appState.moveDocuments(from: indices, to: newOffset)
    }
}
.environment(\.editMode, .constant(.active))
```

If `.onMove` doesn’t allow drag-anywhere on macOS, switch to `draggable`/`dropDestination` on rows and reorder by computing the target index; keep the same `moveDocuments` method.

**Step 3: Manual verification**

- Drag any row to reorder; confirm the order changes immediately.
- Open multiple files with the picker; confirm they append to the bottom in picker order.
- Background the app and relaunch; confirm the order is preserved.

**Step 4: Commit**

```bash
git add Sources/NoteMac/Views/Sidebar.swift
git commit -m "feat: add sidebar drag reorder"
```

### Task 3: Reduce left/right padding in sidebar rows

**Files:**
- Modify: `Sources/NoteMac/Views/Sidebar.swift`

**Step 1: Adjust list row insets**

Change:

```swift
.listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
```

To a tighter inset, e.g.:

```swift
.listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
```

**Step 2: Reduce row horizontal padding**

Change:

```swift
.padding(.horizontal, 10)
```

To a smaller value, e.g.:

```swift
.padding(.horizontal, 6)
```

**Step 3: Manual verification**

- Confirm filename text aligns closer to the edge without clipping.
- Confirm selection highlight still looks correct and the close “x” remains reachable.

**Step 4: Commit**

```bash
git add Sources/NoteMac/Views/Sidebar.swift
git commit -m "style: tighten sidebar row padding"
```

### Task 4: (Optional) Verify session order persistence

**Files:**
- Modify: `Tests/NoteMacTests/SessionStoreTests.swift`

**Step 1: Add a regression test for order preservation**

```swift
@Test("Preserves document order")
func preservesDocumentOrder() throws {
    cleanupSession()
    defer { cleanupSession() }

    let appState = AppState()
    let doc1 = Document(content: "One")
    let doc2 = Document(content: "Two")
    let doc3 = Document(content: "Three")

    appState.documents = [doc2, doc3, doc1]

    try SessionStore.save(appState: appState)
    let loaded = try SessionStore.load()

    guard let sessionData = loaded else {
        Issue.record("Session data should not be nil")
        return
    }

    #expect(sessionData.documents.map { $0.id } == [doc2.id, doc3.id, doc1.id])
}
```

**Step 2: Run tests**

Run: `swift test`
Expected: PASS

**Step 3: Commit**

```bash
git add Tests/NoteMacTests/SessionStoreTests.swift
git commit -m "test: ensure document order persists"
```

