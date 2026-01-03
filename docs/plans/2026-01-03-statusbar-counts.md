# Status Bar Counts Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the status bar encoding/line-ending/type labels with localized character and word counts, updating after a 1000ms debounce.

**Architecture:** Add a small text statistics helper for character and word counts, test it with @superpowers:test-driven-development, then wire StatusBar to use it with a debounced update and localized number formatting.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing.

### Task 1: Text statistics helper + tests

**Files:**
- Create: `Sources/NoteMac/Services/TextStatistics.swift`
- Create: `Tests/NoteMacTests/TextStatisticsTests.swift`

**Step 1: Write the failing test**

```swift
import Testing
@testable import NoteMac

@Suite("Text Statistics Tests")
struct TextStatisticsTests {
    @Test("Counts characters and words for basic text")
    func countsBasicText() {
        let counts = TextStatistics.counts(in: "Hello world")
        #expect(counts.characters == 11)
        #expect(counts.words == 2)
    }

    @Test("Counts empty string as zero")
    func countsEmptyText() {
        let counts = TextStatistics.counts(in: "")
        #expect(counts.characters == 0)
        #expect(counts.words == 0)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `swift test`
Expected: FAIL with compile error like "cannot find 'TextStatistics' in scope".

**Step 3: Write minimal implementation**

```swift
import Foundation

struct TextCounts: Equatable {
    let characters: Int
    let words: Int
}

enum TextStatistics {
    static func counts(in text: String) -> TextCounts {
        return TextCounts(characters: 0, words: 0)
    }
}
```

**Step 4: Run test to verify it fails correctly**

Run: `swift test`
Expected: FAIL with assertion mismatch (characters and words are 0).

**Step 5: Implement real counting**

```swift
enum TextStatistics {
    static func counts(in text: String) -> TextCounts {
        let characters = text.count
        var words = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { _, _, _, _ in
            words += 1
        }
        return TextCounts(characters: characters, words: words)
    }
}
```

**Step 6: Run tests to verify they pass**

Run: `swift test`
Expected: PASS.

**Step 7: Commit**

```bash
git add Tests/NoteMacTests/TextStatisticsTests.swift Sources/NoteMac/Services/TextStatistics.swift
git commit -m "test: add text statistics counts"
```

### Task 2: Status bar wiring + debounce

**Files:**
- Modify: `Sources/NoteMac/Views/MainWindow.swift`
- Modify: `Sources/NoteMac/Views/StatusBar.swift`

**Step 1: Update StatusBar API to accept content**

```swift
struct StatusBar: View {
    let line: Int
    let column: Int
    let content: String

    @State private var charCount = 0
    @State private var wordCount = 0
    @State private var debounceTask: Task<Void, Never>?

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()

    var body: some View {
        HStack(spacing: 16) {
            Text("Ln \(line), Col \(column)")
                .monospacedDigit()

            Spacer()

            let charText = StatusBar.formatter.string(from: NSNumber(value: charCount)) ?? String(charCount)
            let wordText = StatusBar.formatter.string(from: NSNumber(value: wordCount)) ?? String(wordCount)

            Text("\(charText) chars / \(wordText) words")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
        .onAppear {
            let counts = TextStatistics.counts(in: content)
            charCount = counts.characters
            wordCount = counts.words
        }
        .onChange(of: content) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1000))
                let counts = TextStatistics.counts(in: newValue)
                charCount = counts.characters
                wordCount = counts.words
            }
        }
    }
}
```

**Step 2: Wire content in MainWindow**

```swift
StatusBar(
    line: appState.activeDocument?.cursorLine ?? 1,
    column: appState.activeDocument?.cursorColumn ?? 1,
    content: appState.activeDocument?.content ?? ""
)
```

**Step 3: Manual verification**

Run: `swift run`
Expected: Status bar shows "<chars> chars / <words> words" and updates 1 second after typing stops.

**Step 4: Commit**

```bash
git add Sources/NoteMac/Views/StatusBar.swift Sources/NoteMac/Views/MainWindow.swift
git commit -m "feat: show debounced character and word counts"
```
