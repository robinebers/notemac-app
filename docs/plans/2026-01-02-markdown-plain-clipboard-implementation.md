# Always-Markdown + Plain Clipboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Treat every document as Markdown for styling and convert rich pastes to Markdown while forcing copy to be plain text only.

**Architecture:** Keep storage as plain text; apply Markdown styling visually via the existing STTextView plugin for every document. Intercept copy/paste in a custom `STTextView` subclass: copy writes only UTF-8 plain text, paste prefers HTML/RTF → Markdown via Demark, with a plain-text fallback.

**Tech Stack:** SwiftUI, AppKit, STTextView, Demark, swift-markdown, Swift Testing.

---

### Task 1: Add Demark dependency

**Files:**
- Modify: `Package.swift`
- Modify: `Package.resolved` (via `swift package resolve`)

**Step 1: Add Demark package + target dependency**

Update `Package.swift`:

```swift
.dependencies: [
    .package(url: "https://github.com/krzyzanowskim/STTextView", from: "0.9.0"),
    .package(url: "https://github.com/apple/swift-markdown", from: "0.4.0"),
    .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0"),
    .package(url: "https://github.com/steipete/Demark.git", from: "1.0.0")
],
```

and add Demark to the app target dependencies:

```swift
.executableTarget(
    name: "NoteMac",
    dependencies: [
        .product(name: "STTextView", package: "STTextView"),
        .product(name: "Markdown", package: "swift-markdown"),
        .product(name: "Demark", package: "Demark")
    ],
    path: "Sources/NoteMac"
),
```

**Step 2: Resolve packages**

Run:
`swift package resolve`

Expected: `Package.resolved` updated with Demark.

**Step 3: Commit**

```bash
git add Package.swift Package.resolved
git commit -m "feat: add Demark dependency"
```

---

### Task 2: Add failing tests for HTML → Markdown conversion

**Files:**
- Create: `Tests/NoteMacTests/PasteMarkdownConverterTests.swift`

**Step 1: Write the failing test**

```swift
import Testing
@testable import NoteMac

@Suite("Paste Markdown Converter")
struct PasteMarkdownConverterTests {
    @Test("Converts basic HTML to Markdown")
    @MainActor
    func convertsBasicHTML() async throws {
        let converter = PasteMarkdownConverter()
        let html = """
        <h1>Hello</h1>
        <p>This is <strong>bold</strong> and <em>italic</em>.</p>
        <ul><li>One</li></ul>
        """

        let markdown = try await converter.convertHTMLToMarkdown(html)

        #expect(markdown.contains("# Hello"))
        #expect(markdown.contains("**bold**"))
        #expect(markdown.contains("*italic*") || markdown.contains("_italic_"))
        #expect(markdown.contains("- One"))
    }
}
```

**Step 2: Run tests to verify failure**

Run: `swift test`

Expected: FAIL with “cannot find type ‘PasteMarkdownConverter’ in scope”.

**Step 3: Commit**

```bash
git add Tests/NoteMacTests/PasteMarkdownConverterTests.swift
git commit -m "test: add PasteMarkdownConverter test"
```

---

### Task 3: Implement PasteMarkdownConverter service

**Files:**
- Create: `Sources/NoteMac/Services/PasteMarkdownConverter.swift`

**Step 1: Implement converter (Demark-based)**

```swift
import AppKit
import Demark

@MainActor
final class PasteMarkdownConverter {
    private let demark: Demark
    private let options: DemarkOptions

    init(
        demark: Demark = Demark(),
        options: DemarkOptions = DemarkOptions(
            headingStyle: .atx,
            bulletListMarker: "-",
            codeBlockStyle: .fenced
        )
    ) {
        self.demark = demark
        self.options = options
    }

    func convertHTMLToMarkdown(_ html: String) async throws -> String {
        try await demark.convertToMarkdown(html, options: options)
    }

    func markdownString(from pasteboard: NSPasteboard) async -> String? {
        if let html = htmlString(from: pasteboard) {
            if let markdown = try? await convertHTMLToMarkdown(html),
               !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return markdown
            }
        }

        if let plain = pasteboard.string(forType: .string) {
            return plain
        }

        return nil
    }

    private func htmlString(from pasteboard: NSPasteboard) -> String? {
        if let html = pasteboard.string(forType: .html) {
            return html
        }

        if let rtfData = pasteboard.data(forType: .rtf) {
            return htmlString(fromRTFData: rtfData, documentType: .rtf)
        }

        if let rtfdData = pasteboard.data(forType: .rtfd) {
            return htmlString(fromRTFData: rtfdData, documentType: .rtfd)
        }

        return nil
    }

    private func htmlString(
        fromRTFData data: Data,
        documentType: NSAttributedString.DocumentType
    ) -> String? {
        let readOptions: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: documentType
        ]
        guard let attributed = try? NSAttributedString(
            data: data,
            options: readOptions,
            documentAttributes: nil
        ) else {
            return nil
        }

        let exportOptions: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html
        ]
        guard let htmlData = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: exportOptions
        ) else {
            return nil
        }

        return String(data: htmlData, encoding: .utf8)
    }
}
```

**Step 2: Run tests to verify pass**

Run: `swift test`

Expected: PASS.

**Step 3: Commit**

```bash
git add Sources/NoteMac/Services/PasteMarkdownConverter.swift
git commit -m "feat: add paste markdown converter"
```

---

### Task 4: Add NoteMacTextView for plain copy + markdown paste

**Files:**
- Create: `Sources/NoteMac/Views/NoteMacTextView.swift`

**Step 1: Implement custom text view**

```swift
import AppKit
import STTextView

final class NoteMacTextView: STTextView {
    private let pasteConverter = PasteMarkdownConverter()

    override func writablePasteboardTypes(for range: NSRange) -> [NSPasteboard.PasteboardType] {
        [.string]
    }

    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]?) -> Bool {
        let selection = selectedRange()
        let source = string as NSString
        let selectedText = selection.length > 0 ? source.substring(with: selection) : ""

        pboard.clearContents()
        pboard.setString(selectedText, forType: .string)
        return true
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        Task { @MainActor in
            if let markdown = await pasteConverter.markdownString(from: pasteboard) {
                insertText(markdown, replacementRange: selectedRange())
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add Sources/NoteMac/Views/NoteMacTextView.swift
git commit -m "feat: force plain copy and markdown paste"
```

---

### Task 5: Make markdown styling always-on and use NoteMacTextView

**Files:**
- Modify: `Sources/NoteMac/Views/EditorView.swift`

**Step 1: Use NoteMacTextView scrollable factory**

Change in `makeNSView`:

```swift
let scrollView = NoteMacTextView.scrollableTextView()
let textView = scrollView.documentView as! NoteMacTextView
```

**Step 2: Always add the markdown styling plugin**

Replace markdown-gated plugin logic with:

```swift
let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
let plugin = MarkdownStylingPlugin(baseFont: baseFont)
textView.addPlugin(plugin)
context.coordinator.markdownPlugin = plugin
```

**Step 3: Remove isMarkdown toggling + always apply MarkdownStyler on external changes**

- Delete `document.isMarkdown` checks in `updateNSView`.
- Always apply `MarkdownStyler.apply(...)` after `setAttributedString(...)`.
- For font changes, always use `MarkdownStyler.apply(...)` and update `typingAttributes[.font]`.

**Step 4: Commit**

```bash
git add Sources/NoteMac/Views/EditorView.swift
git commit -m "feat: apply markdown styling to all files"
```

---

### Task 6: Update UI indicators to reflect always-Markdown

**Files:**
- Modify: `Sources/NoteMac/Views/MainWindow.swift`
- Modify: `Sources/NoteMac/Views/Sidebar.swift`

**Step 1: Status bar document type**

```swift
documentType: "Markdown"
```

**Step 2: Sidebar icon**

```swift
Image(systemName: "doc.text")
```

**Step 3: Commit**

```bash
git add Sources/NoteMac/Views/MainWindow.swift Sources/NoteMac/Views/Sidebar.swift
git commit -m "chore: align UI with always-markdown"
```

---

### Task 7: Manual verification + full test run

**Files:**
- None (runtime validation)

**Step 1: Run tests**

Run: `swift test`

Expected: PASS.

**Step 2: Manual verification checklist**

- Open a `.txt` file and confirm markdown styling appears (e.g., `# Heading`, `**bold**`).
- Copy from NoteMac into another app (TextEdit/Notes) and confirm **plain text only** (no fonts/formatting).
- Copy rich text from a browser/Notes into NoteMac and confirm it pastes as Markdown.
- Copy plain text that already contains markdown syntax and confirm it pastes **unchanged**.

**Step 3: Commit (if any tweaks)**

```bash
git add -A
git commit -m "test: verify markdown styling + clipboard behavior"
```
