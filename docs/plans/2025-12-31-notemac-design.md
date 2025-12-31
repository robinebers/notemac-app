# NoteMac Design Document

A native macOS plain text editor channeling the radical simplicity of Windows 95/98/XP Notepad with macOS Tahoe's Liquid Glass aesthetic.

---

## 1. Core Concept

### Philosophy
- Open instantly, type immediately
- No bloat, no preferences panels with 50 options
- Text is text - what you see is what you get
- Get out of the user's way

### Core Features
- Plain text editing with optional markdown syntax highlighting
- Tab-based document management (multiple files open)
- Auto-persistence of unsaved documents across launches
- Standard file operations (New, Open, Save, Save As)
- Find & Replace
- Word wrap toggle
- Line/column indicator in status bar

### Explicitly Not Included
- Rich text formatting
- Markdown preview/rendering
- Plugins or extensions
- Cloud sync
- AI features
- Spell check (rely on macOS system)
- Preferences beyond essentials (font size, word wrap default)

### Supported Files
- `.txt` - Plain text
- `.md` - Markdown

---

## 2. User Interface

### Window Structure

```
┌─────────────────────────────────────────────────────┐
│ ● ● ●  [Tab1] [Tab2] [+]          NoteMac     │ ← Liquid Glass toolbar
├─────────────────────────────────────────────────────┤
│                                                     │
│  Your text goes here...                             │
│  Just plain monospace goodness.                     │
│                                                     │
│                                                     │
│                                                     │ ← Solid background
│                                                     │
│                                                     │
│                                                     │
├─────────────────────────────────────────────────────┤
│ Ln 3, Col 15    UTF-8    LF    Plain Text     │ ← Status bar
└─────────────────────────────────────────────────────┘
```

### Toolbar (Liquid Glass)
- Traffic lights (close/minimize/zoom) on left
- Document tabs in center - minimal pill-shaped design
- "+" button to create new tab
- Unified title bar style (no separate title)

### Content Area
- Solid, non-translucent background for readability
- Default: monospace font (SF Mono or Menlo), ~13pt
- Generous line height for comfortable reading
- Subtle line numbers gutter (optional, off by default)

### Status Bar
- Line/column position
- File encoding (UTF-8)
- Line ending style (LF/CRLF)
- Document type indicator (Plain Text / Markdown)

### Color Modes
- Follows system light/dark mode automatically
- Light: off-white background, dark text
- Dark: dark gray background, light text

### Visual Personality
- Retro-minimal aesthetic
- Monospace font default
- Minimal chrome
- Evokes 90s Notepad simplicity

---

## 3. Data Model & Persistence

### Document Model

```swift
@Observable
final class Document: Identifiable {
    let id: UUID
    var content: String
    var filePath: URL?              // nil = untitled/scratch
    var isModified: Bool
    var cursorPosition: (line: Int, column: Int)
    var scrollPosition: CGFloat
    var createdAt: Date
    var lastModifiedAt: Date
}
```

### Session Persistence

**On quit, the app saves:**
- All open documents (content, cursor, scroll position)
- Tab order
- Active tab
- Window size/position

**On launch:**
- Restores exact previous state
- Untitled documents with content reappear as-is
- Files are re-opened (with "file moved/deleted" handling if needed)

### Storage Location
- `~/Library/Application Support/NoteMac/session.json` - session state
- `~/Library/Application Support/NoteMac/drafts/` - unsaved document content

### File Handling
- Standard macOS Open/Save dialogs
- Detects encoding on open (UTF-8, UTF-16, ASCII, etc.)
- Saves as UTF-8 by default
- Watches open files for external changes (prompt to reload)

### Dirty State
- Modified indicator (dot) on tab
- "Save changes?" prompt on close if modified
- ⌘S saves, ⌘⇧S opens Save As

---

## 4. Markdown Syntax Highlighting

Lightweight, non-intrusive coloring while editing. No live preview, no rendering.

### Highlighted Elements

| Element | Visual Treatment |
|---------|------------------|
| `# Headers` | Bold, slightly larger, accent color |
| `**bold**` | Bold text color |
| `*italic*` | Italic text color |
| `` `inline code` `` | Monospace, subtle background tint |
| `[links](url)` | Link text in accent color, URL dimmed |
| `- list items` | Bullet/dash in accent color |
| `1. numbered lists` | Number in accent color |
| `> blockquotes` | Dimmed/muted color |
| `---` horizontal rules | Dimmed |
| ``` code blocks ``` | Subtle background tint for entire block |

### Detection
- File extension `.md` → markdown highlighting enabled
- `.txt` → plain text, no highlighting
- User can toggle per-document via status bar click

### Colors
- Follow system accent color for links/headers
- Muted grays for syntax characters (`#`, `**`, etc.)
- Respect light/dark mode

---

## 5. Menu Bar & Keyboard Shortcuts

### Menu Structure

```
NoteMac
├── About NoteMac
├── Settings... (⌘,)        → Font size, default word wrap
├── Hide/Quit

File
├── New Tab (⌘N)
├── Open... (⌘O)
├── Save (⌘S)
├── Save As... (⌘⇧S)
├── Close Tab (⌘W)

Edit
├── Undo/Redo (⌘Z / ⌘⇧Z)
├── Cut/Copy/Paste (standard)
├── Select All (⌘A)
├── Find... (⌘F)
├── Find & Replace... (⌘⌥F)

View
├── Word Wrap (⌘⌥W)         → Toggle
├── Show Line Numbers        → Toggle (off by default)

Window
├── (standard macOS window menu)
```

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘N` | New tab |
| `⌘O` | Open file |
| `⌘S` | Save |
| `⌘⇧S` | Save As |
| `⌘W` | Close tab |
| `⌘F` | Find |
| `⌘⌥F` | Find & Replace |
| `⌘G` / `⌘⇧G` | Find next/previous |
| `⌘⌥W` | Toggle word wrap |
| `⌘,` | Settings |

---

## 6. Technical Implementation

### Tech Stack (December 2025)

| Layer | Choice | Rationale |
|-------|--------|-----------|
| **Text Engine** | [STTextView](https://github.com/krzyzanowskim/STTextView) | Purpose-built macOS text view, performant, SwiftUI bindings, incremental search built-in |
| **UI Framework** | SwiftUI + AppKit integration | SwiftUI for chrome, STTextView for editor |
| **State** | `@Observable` macro (Swift 5.9+) | Modern, cleaner than `@ObservableObject` |
| **Concurrency** | Swift 6 strict concurrency | Future-proof, async file operations |
| **Persistence** | `Codable` + JSON | Simple, no dependencies |
| **Syntax Highlighting** | Custom `NSTextStorage` attributes | Lightweight, no third-party lib needed |

### Why STTextView
- Built-in incremental search (`isIncrementalSearchingEnabled`)
- Better SwiftUI integration out of the box
- Actively maintained, macOS-focused
- Handles undo/redo properly

### Project Structure

```
NoteMac/
├── NoteMacApp.swift              # @main, WindowGroup
├── Models/
│   ├── Document.swift            # @Observable document model
│   └── AppState.swift            # @Observable app state
├── Views/
│   ├── MainWindow.swift          # Window container
│   ├── TabBar.swift              # Liquid Glass tabs
│   ├── Editor.swift              # STTextView wrapper
│   └── StatusBar.swift           # Line/col display
├── Services/
│   ├── SessionStore.swift        # Persist/restore session
│   └── MarkdownStyler.swift      # Syntax highlighting
└── NoteMac.entitlements          # Sandbox, file access
```

### Dependencies

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/krzyzanowskim/STTextView", from: "0.9.0")
]
```

### Minimum Requirements
- macOS 26 (Tahoe) - for Liquid Glass
- Swift 6
- Xcode 17+

---

## 7. Design Decisions Summary

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| Primary use case | Quick scratch pad | Stay true to Notepad's soul |
| Persistence | Hybrid (auto-persist + files) | Modern convenience without losing simplicity |
| Tabs | Document tabs only | Clean mental model |
| Markdown | Syntax highlighting only | Useful without complexity |
| Liquid Glass | Toolbar only | Readable content area |
| Visual style | Retro-minimal, monospace | Nostalgic Notepad feel |
| Shortcuts | Standard macOS only | No learning curve |
| File types | `.txt` and `.md` only | Focused scope |

---

## 8. Future Considerations (Not in v1)

These are explicitly out of scope for v1 but could be considered later:

- iCloud sync for drafts
- Quick Open (⌘P) for recent files
- Multiple windows
- Print support
- Export to PDF
- Custom themes

---

*Document created: 2025-12-31*
*Status: Ready for implementation*
