# Status Bar Selection Counts Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When text is selected, show character/word counts for the selection; otherwise show full document counts, with a 300ms debounce for updates.

**Architecture:** Track selection range on Document, extend text statistics to compute counts for a selection, and update StatusBar to debounce on both content and selection changes using the existing formatter.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, STTextView.

### Task 1: Selection-aware counts (TDD)

**Files:**
- Modify: `Sources/NoteMac/Services/TextStatistics.swift`
- Create: `Tests/NoteMacTests/TextStatisticsSelectionTests.swift`

**Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import NoteMac

@Suite("Text Statistics Selection Tests")
struct TextStatisticsSelectionTests {
    @Test("Counts selection when range is valid and non-empty")
    func countsSelection() {
        let text = "Hello world"
        let range = NSRange(location: 0, length: 5) // "Hello"
        let counts = TextStatistics.counts(in: text, selectionRange: range)
        #expect(counts.characters == 5)
        #expect(counts.words == 1)
    }

    @Test("Falls back to full text for empty selection")
    func fallsBackForEmptySelection() {
        let text = "Hello world"
        let range = NSRange(location: 0, length: 0)
        let counts = TextStatistics.counts(in: text, selectionRange: range)
        #expect(counts.characters == 11)
        #expect(counts.words == 2)
    }

    @Test("Falls back to full text for invalid range")
    func fallsBackForInvalidRange() {
        let text = "Hello world"
        let range = NSRange(location: 999, length: 5)
        let counts = TextStatistics.counts(in: text, selectionRange: range)
        #expect(counts.characters == 11)
        #expect(counts.words == 2)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test --filter TextStatisticsSelectionTests`
Expected: FAIL with "cannot find 'counts(in:selectionRange:)'" or similar.

**Step 3: Add minimal API**

```swift
static func counts(in text: String, selectionRange: NSRange) -> TextCounts {
    return counts(in: text)
}
```

**Step 4: Run test to verify it fails correctly**

Run: `swift test --filter TextStatisticsSelectionTests`
Expected: FAIL for the selection-specific expectations.

**Step 5: Implement selection logic**

```swift
static func counts(in text: String, selectionRange: NSRange) -> TextCounts {
    guard selectionRange.length > 0,
          let range = Range(selectionRange, in: text) else {
        return counts(in: text)
    }
    let substring = String(text[range])
    return counts(in: substring)
}
```

**Step 6: Run tests to verify they pass**

Run: `swift test --filter TextStatisticsSelectionTests`
Expected: PASS.

**Step 7: Commit**

```bash
git add Tests/NoteMacTests/TextStatisticsSelectionTests.swift Sources/NoteMac/Services/TextStatistics.swift
git commit -m "test: add selection-aware text counts"
```

### Task 2: Wire selection + debounce update

**Files:**
- Modify: `Sources/NoteMac/Models/Document.swift`
- Modify: `Sources/NoteMac/Views/EditorView.swift`
- Modify: `Sources/NoteMac/Views/StatusBar.swift`
- Modify: `Sources/NoteMac/Views/MainWindow.swift`

**Step 1: Track selection range in Document**

Add to Document properties:

```swift
var selectionRange: NSRange
```

Initialize in `init` with `NSRange(location: 0, length: 0)`.

**Step 2: Update selection in EditorCoordinator**

In `textViewDidChangeSelection`, after updating cursor position:

```swift
self.document.selectionRange = textView.selectedRange()
```

**Step 3: Pass selection into StatusBar**

Update `StatusBar` signature to include selection range and reduce debounce to 300ms.

```swift
StatusBar(
    line: appState.activeDocument?.cursorLine ?? 1,
    column: appState.activeDocument?.cursorColumn ?? 1,
    content: appState.activeDocument?.content ?? "",
    selectionRange: appState.activeDocument?.selectionRange ?? NSRange(location: 0, length: 0)
)
```

**Step 4: Use selection-aware counts + 300ms debounce**

In `StatusBar`, compute counts with the selection-aware helper:

```swift
private func updateCounts(for text: String, selectionRange: NSRange) {
    let counts = TextStatistics.counts(in: text, selectionRange: selectionRange)
    charCount = counts.characters
    wordCount = counts.words
}
```

Update the `onChange` handlers to watch both `content` and `selectionRange`, cancel and restart the debounce task, and set sleep to 300ms.

**Step 5: Manual verification**

Run: `swift run`
Expected: selecting text updates counts (after ~300ms) for selection; no selection shows full counts.

**Step 6: Commit**

```bash
git add Sources/NoteMac/Models/Document.swift Sources/NoteMac/Views/EditorView.swift Sources/NoteMac/Views/StatusBar.swift Sources/NoteMac/Views/MainWindow.swift
git commit -m "feat: show selection counts in status bar"
```

