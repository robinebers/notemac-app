# Bear-Style Hybrid Markdown Styling

## Overview

Implement live Markdown styling where syntax characters remain visible but dimmed (~40% opacity) while content is styled (bold, italic, heading sizes, etc.). This provides a hybrid editing experience similar to Bear Notes.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Scope | Standard first, Bear extras later | Phase 1: headings, bold, italic, code, links, strikethrough, blockquotes, lists |
| Trigger | Markdown files only | Uses existing `Document.isMarkdown` property |
| Parser | Apple's swift-markdown | Native, well-maintained, CommonMark compliant |
| Syntax styling | Dim to 40% opacity | Matches Bear's approach - visible but subtle |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ EditorView (existing)                               │
│  └── STTextView                                     │
│       ├── textViewDidChangeText → triggers styling  │
│       └── NSAttributedString receives styles        │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│ MarkdownStyler (new)                                │
│  ├── parse(content: String) → Markdown.Document    │
│  ├── collectRanges() → [StyledRange]               │
│  └── apply(to textView: STTextView)                │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│ swift-markdown (Apple library)                      │
│  └── CommonMark parser with MarkupWalker           │
└─────────────────────────────────────────────────────┘
```

## Style Definitions

| Element | Content Style | Syntax Style |
|---------|--------------|--------------|
| Heading 1 | 1.5x font size, bold | `#` dimmed 40% |
| Heading 2 | 1.3x font size, bold | `##` dimmed 40% |
| Heading 3-6 | 1.15x font size, bold | `###...` dimmed 40% |
| Bold | `.bold` weight | `**` dimmed 40% |
| Italic | `.italic` trait | `*` or `_` dimmed 40% |
| Inline code | Monospace + subtle background | `` ` `` dimmed 40% |
| Links | Blue color, no underline | `[`, `]()` dimmed 40% |
| Strikethrough | `.strikethrough` attribute | `~~` dimmed 40% |
| Blockquote | Italic + left indent | `>` dimmed 40% |
| List items | Normal text | `-`, `*`, `1.` dimmed 40% |

## Implementation Plan

### Step 1: Create MarkdownStyler Service

**File:** `Sources/NoteMac/Services/MarkdownStyler.swift`

```swift
import AppKit
import Markdown
import STTextView

struct StyledRange {
    let range: NSRange
    let style: StyleType

    enum StyleType {
        case heading(level: Int)
        case bold
        case italic
        case inlineCode
        case link(url: String)
        case strikethrough
        case blockquote
        case listMarker
        case syntax
    }
}

struct MarkdownStyler {
    static let syntaxOpacity: CGFloat = 0.4

    static func apply(to textView: STTextView, baseFont: NSFont?) { ... }
}
```

Key components:
- `StyledRange` struct to hold range + style type
- `MarkdownRangeCollector: MarkupWalker` to traverse AST
- `apply(to:baseFont:)` to apply collected styles to text view

### Step 2: Implement MarkupWalker

Use swift-markdown's `MarkupWalker` protocol to visit each node:

```swift
struct MarkdownRangeCollector: MarkupWalker {
    let source: String
    var ranges: [StyledRange] = []

    mutating func visitStrong(_ strong: Strong) -> () {
        // Collect content range with .bold style
        // Collect delimiter ranges with .syntax style
        descendInto(strong)
    }

    mutating func visitHeading(_ heading: Heading) -> () {
        // Collect heading range with .heading(level:) style
        // Collect # prefix with .syntax style
        descendInto(heading)
    }

    // ... similar for Emphasis, InlineCode, Link, Strikethrough, BlockQuote, ListItem
}
```

### Step 3: Integrate with EditorCoordinator

**File:** `Sources/NoteMac/Views/EditorView.swift`

Add debounced styling to `textViewDidChangeText`:

```swift
// In EditorCoordinator
private var stylingWorkItem: DispatchWorkItem?

nonisolated func textViewDidChangeText(_ notification: Notification) {
    // ... existing content update code ...

    // NEW: Apply Markdown styling if applicable
    if self.document.isMarkdown {
        self.scheduleMarkdownStyling(textView: textView)
    }
}

private func scheduleMarkdownStyling(textView: STTextView) {
    stylingWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self, weak textView] in
        guard let textView else { return }
        MarkdownStyler.apply(to: textView, baseFont: textView.font)
    }

    stylingWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
}
```

Also apply styling on file open in `makeNSView` when `document.isMarkdown`.

### Step 4: Handle Edge Cases

1. **Cursor position preservation** - Save/restore cursor after applying attributes
2. **Dark mode** - Use semantic colors (`NSColor.labelColor.withAlphaComponent(0.4)`)
3. **Font changes** - Re-apply styling when base font changes
4. **Large files** - Consider async parsing for files > 100KB

## Files to Create/Modify

| File | Action | Lines |
|------|--------|-------|
| `Package.swift` | Modify | Add swift-markdown dependency ✓ |
| `Sources/NoteMac/Services/MarkdownStyler.swift` | Create | ~150 LOC |
| `Sources/NoteMac/Views/EditorView.swift` | Modify | +30 LOC |

## Phase 2: Bear Extras (Future)

- Code blocks with syntax highlighting
- Task lists with checkboxes
- Tables
- Footnotes
- Image previews
- Highlighting (`==text==`)

## Testing Checklist

- [ ] Headings H1-H6 styled correctly with dimmed `#` characters
- [ ] Bold text styled with dimmed `**` delimiters
- [ ] Italic text styled with dimmed `*` or `_` delimiters
- [ ] Inline code has monospace font and background
- [ ] Links are blue with dimmed `[]()` syntax
- [ ] Strikethrough renders with dimmed `~~`
- [ ] Blockquotes indented with dimmed `>`
- [ ] List markers dimmed
- [ ] Non-Markdown files (.txt, .swift, etc.) not affected
- [ ] Dark mode colors work correctly
- [ ] Performance acceptable on large files
- [ ] Cursor position preserved after styling
