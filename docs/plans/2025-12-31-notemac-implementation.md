# NoteMac Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a minimalist macOS plain text editor inspired by Windows Notepad with Liquid Glass aesthetics.

**Architecture:** SwiftUI app shell with STTextView for text editing. @Observable models for state. Session persistence via Codable JSON. Markdown syntax highlighting via NSTextStorage attributes.

**Tech Stack:** Swift 6, SwiftUI, AppKit (STTextView), macOS 26 (Tahoe)

---

## Phase 1: Project Foundation

### Task 1: Create Swift Package Structure

**Files:**
- Create: `Package.swift`
- Create: `Sources/NoteMac/NoteMacApp.swift`
- Create: `Sources/NoteMac/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Tests/NoteMacTests/NoteMacTests.swift`

**Step 1: Initialize the package directory structure**

```bash
cd /Users/rebers/conductor/workspaces/notemac-app/bangalore
mkdir -p Sources/NoteMac/Models
mkdir -p Sources/NoteMac/Views
mkdir -p Sources/NoteMac/Services
mkdir -p Sources/NoteMac/Resources/Assets.xcassets/AppIcon.appiconset
mkdir -p Tests/NoteMacTests
```

**Step 2: Create Package.swift**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NoteMac",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "NoteMac", targets: ["NoteMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/STTextView", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "NoteMac",
            dependencies: [
                .product(name: "STTextViewSwiftUI", package: "STTextView")
            ],
            path: "Sources/NoteMac",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NoteMacTests",
            dependencies: ["NoteMac"],
            path: "Tests/NoteMacTests"
        )
    ]
)
```

**Step 3: Create minimal app entry point**

Create `Sources/NoteMac/NoteMacApp.swift`:

```swift
import SwiftUI

@main
struct NoteMacApp: App {
    var body: some Scene {
        WindowGroup {
            Text("NoteMac")
                .frame(width: 600, height: 400)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
```

**Step 4: Create AppIcon Contents.json**

Create `Sources/NoteMac/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Step 5: Create placeholder test file**

Create `Tests/NoteMacTests/NoteMacTests.swift`:

```swift
import Testing

@Suite("NoteMac Tests")
struct NoteMacTests {
    @Test("App launches")
    func appLaunches() {
        #expect(true)
    }
}
```

**Step 6: Verify package builds**

```bash
cd /Users/rebers/conductor/workspaces/notemac-app/bangalore
swift build
```

Expected: Build succeeds with no errors.

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: initialize NoteMac Swift package with STTextView dependency"
```

---

### Task 2: Create Document Model

**Files:**
- Create: `Sources/NoteMac/Models/Document.swift`
- Create: `Tests/NoteMacTests/DocumentTests.swift`

**Step 1: Write failing test for Document creation**

Create `Tests/NoteMacTests/DocumentTests.swift`:

```swift
import Testing
@testable import NoteMac

@Suite("Document Tests")
struct DocumentTests {
    @Test("Creates new untitled document")
    func createsNewDocument() {
        let doc = Document()

        #expect(doc.content == "")
        #expect(doc.filePath == nil)
        #expect(doc.isModified == false)
        #expect(doc.title == "Untitled")
    }

    @Test("Tracks modification state")
    func tracksModification() {
        let doc = Document()
        doc.content = "Hello"

        #expect(doc.isModified == true)
    }

    @Test("Derives title from file path")
    func derivesTitleFromPath() {
        let doc = Document()
        doc.filePath = URL(fileURLWithPath: "/Users/test/notes.md")

        #expect(doc.title == "notes.md")
    }

    @Test("Detects markdown from extension")
    func detectsMarkdown() {
        let txtDoc = Document()
        txtDoc.filePath = URL(fileURLWithPath: "/test.txt")
        #expect(txtDoc.isMarkdown == false)

        let mdDoc = Document()
        mdDoc.filePath = URL(fileURLWithPath: "/test.md")
        #expect(mdDoc.isMarkdown == true)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
swift test --filter DocumentTests
```

Expected: FAIL - Document type not found.

**Step 3: Implement Document model**

Create `Sources/NoteMac/Models/Document.swift`:

```swift
import Foundation
import Observation

@Observable
final class Document: Identifiable {
    let id: UUID
    var content: String {
        didSet {
            if content != oldValue {
                isModified = true
                lastModifiedAt = Date()
            }
        }
    }
    var filePath: URL?
    private(set) var isModified: Bool
    var cursorLine: Int
    var cursorColumn: Int
    var scrollPosition: CGFloat
    let createdAt: Date
    private(set) var lastModifiedAt: Date

    var title: String {
        filePath?.lastPathComponent ?? "Untitled"
    }

    var isMarkdown: Bool {
        guard let ext = filePath?.pathExtension.lowercased() else { return false }
        return ext == "md" || ext == "markdown"
    }

    init(
        id: UUID = UUID(),
        content: String = "",
        filePath: URL? = nil
    ) {
        self.id = id
        self.content = content
        self.filePath = filePath
        self.isModified = false
        self.cursorLine = 1
        self.cursorColumn = 1
        self.scrollPosition = 0
        self.createdAt = Date()
        self.lastModifiedAt = Date()
    }

    func markSaved() {
        isModified = false
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
swift test --filter DocumentTests
```

Expected: All 4 tests PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Document model with modification tracking"
```

---

### Task 3: Create AppState Model

**Files:**
- Create: `Sources/NoteMac/Models/AppState.swift`
- Create: `Tests/NoteMacTests/AppStateTests.swift`

**Step 1: Write failing tests for AppState**

Create `Tests/NoteMacTests/AppStateTests.swift`:

```swift
import Testing
@testable import NoteMac

@Suite("AppState Tests")
struct AppStateTests {
    @Test("Starts with one empty document")
    func startsWithOneDocument() {
        let state = AppState()

        #expect(state.documents.count == 1)
        #expect(state.activeDocumentID != nil)
    }

    @Test("Can add new document")
    func addsNewDocument() {
        let state = AppState()
        let initialCount = state.documents.count

        state.newDocument()

        #expect(state.documents.count == initialCount + 1)
    }

    @Test("Can close document")
    func closesDocument() {
        let state = AppState()
        state.newDocument()
        let docToClose = state.documents.last!

        state.closeDocument(id: docToClose.id)

        #expect(!state.documents.contains { $0.id == docToClose.id })
    }

    @Test("Cannot close last document - creates new one")
    func cannotCloseLastDocument() {
        let state = AppState()
        let onlyDoc = state.documents.first!

        state.closeDocument(id: onlyDoc.id)

        #expect(state.documents.count == 1)
        #expect(state.documents.first?.id != onlyDoc.id)
    }

    @Test("Active document returns correct document")
    func activeDocumentWorks() {
        let state = AppState()

        #expect(state.activeDocument != nil)
        #expect(state.activeDocument?.id == state.activeDocumentID)
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test --filter AppStateTests
```

Expected: FAIL - AppState type not found.

**Step 3: Implement AppState model**

Create `Sources/NoteMac/Models/AppState.swift`:

```swift
import Foundation
import Observation

@Observable
final class AppState {
    var documents: [Document]
    var activeDocumentID: UUID?
    var wordWrapEnabled: Bool
    var showLineNumbers: Bool
    var fontSize: CGFloat

    var activeDocument: Document? {
        documents.first { $0.id == activeDocumentID }
    }

    init() {
        let initialDoc = Document()
        self.documents = [initialDoc]
        self.activeDocumentID = initialDoc.id
        self.wordWrapEnabled = true
        self.showLineNumbers = false
        self.fontSize = 13
    }

    func newDocument() {
        let doc = Document()
        documents.append(doc)
        activeDocumentID = doc.id
    }

    func closeDocument(id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }

        documents.remove(at: index)

        // If we closed the active document, select another
        if activeDocumentID == id {
            activeDocumentID = documents.last?.id
        }

        // Never leave with zero documents
        if documents.isEmpty {
            newDocument()
        }
    }

    func setActiveDocument(id: UUID) {
        if documents.contains(where: { $0.id == id }) {
            activeDocumentID = id
        }
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
swift test --filter AppStateTests
```

Expected: All 5 tests PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add AppState model for document management"
```

---

## Phase 2: Core Views

### Task 4: Create Editor View (STTextView Wrapper)

**Files:**
- Create: `Sources/NoteMac/Views/EditorView.swift`

**Step 1: Create EditorView with STTextView**

Create `Sources/NoteMac/Views/EditorView.swift`:

```swift
import SwiftUI
import STTextViewSwiftUI

struct EditorView: View {
    @Bindable var document: Document
    let fontSize: CGFloat
    let wordWrap: Bool

    var body: some View {
        STTextViewUI(
            text: $document.content,
            options: [
                .wrapLines,
                .highlightSelectedLine
            ],
            plugins: []
        )
        .textViewFont(.monospacedSystemFont(ofSize: fontSize, weight: .regular))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EditorView(
        document: Document(content: "Hello, NoteMac!"),
        fontSize: 13,
        wordWrap: true
    )
    .frame(width: 400, height: 300)
}
```

**Step 2: Verify it compiles**

```bash
swift build
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add EditorView with STTextView integration"
```

---

### Task 5: Create Status Bar View

**Files:**
- Create: `Sources/NoteMac/Views/StatusBar.swift`

**Step 1: Create StatusBar view**

Create `Sources/NoteMac/Views/StatusBar.swift`:

```swift
import SwiftUI

struct StatusBar: View {
    let line: Int
    let column: Int
    let encoding: String
    let lineEnding: String
    let documentType: String

    var body: some View {
        HStack(spacing: 16) {
            Text("Ln \(line), Col \(column)")
                .monospacedDigit()

            Spacer()

            Text(encoding)

            Text(lineEnding)

            Text(documentType)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }
}

#Preview {
    VStack {
        Spacer()
        StatusBar(
            line: 42,
            column: 15,
            encoding: "UTF-8",
            lineEnding: "LF",
            documentType: "Markdown"
        )
    }
    .frame(width: 500, height: 100)
}
```

**Step 2: Verify it compiles**

```bash
swift build
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add StatusBar view"
```

---

### Task 6: Create Tab Bar View

**Files:**
- Create: `Sources/NoteMac/Views/TabBar.swift`

**Step 1: Create TabBar view with Liquid Glass effect**

Create `Sources/NoteMac/Views/TabBar.swift`:

```swift
import SwiftUI

struct TabBar: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            // Tabs
            ForEach(appState.documents) { doc in
                TabButton(
                    title: doc.title,
                    isActive: doc.id == appState.activeDocumentID,
                    isModified: doc.isModified,
                    onSelect: {
                        appState.setActiveDocument(id: doc.id)
                    },
                    onClose: {
                        appState.closeDocument(id: doc.id)
                    }
                )
            }

            // New tab button
            Button(action: { appState.newDocument() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

struct TabButton: View {
    let title: String
    let isActive: Bool
    let isModified: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            // Modified indicator or close button
            Group {
                if isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(.plain)
                } else if isModified {
                    Circle()
                        .fill(.primary.opacity(0.5))
                        .frame(width: 6, height: 6)
                } else {
                    Color.clear
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 12)

            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    let state = AppState()
    state.documents[0].content = "Modified"
    state.newDocument()
    state.documents[1].filePath = URL(fileURLWithPath: "/test/notes.md")

    return VStack {
        TabBar(appState: state)
        Spacer()
    }
    .frame(width: 500, height: 100)
}
```

**Step 2: Verify it compiles**

```bash
swift build
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add TabBar view with tab management"
```

---

### Task 7: Create Main Window View

**Files:**
- Create: `Sources/NoteMac/Views/MainWindow.swift`
- Modify: `Sources/NoteMac/NoteMacApp.swift`

**Step 1: Create MainWindow that composes all views**

Create `Sources/NoteMac/Views/MainWindow.swift`:

```swift
import SwiftUI

struct MainWindow: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBar(appState: appState)

            Divider()

            // Editor
            if let doc = appState.activeDocument {
                EditorView(
                    document: doc,
                    fontSize: appState.fontSize,
                    wordWrap: appState.wordWrapEnabled
                )
            } else {
                ContentUnavailableView(
                    "No Document",
                    systemImage: "doc.text",
                    description: Text("Press ⌘N to create a new document")
                )
            }

            Divider()

            // Status bar
            StatusBar(
                line: appState.activeDocument?.cursorLine ?? 1,
                column: appState.activeDocument?.cursorColumn ?? 1,
                encoding: "UTF-8",
                lineEnding: "LF",
                documentType: appState.activeDocument?.isMarkdown == true ? "Markdown" : "Plain Text"
            )
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    MainWindow(appState: AppState())
        .frame(width: 600, height: 400)
}
```

**Step 2: Update NoteMacApp to use MainWindow**

Modify `Sources/NoteMac/NoteMacApp.swift`:

```swift
import SwiftUI

@main
struct NoteMacApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindow(appState: appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    appState.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
```

**Step 3: Verify it compiles**

```bash
swift build
```

Expected: Build succeeds.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add MainWindow composing TabBar, Editor, and StatusBar"
```

---

## Phase 3: File Operations

### Task 8: Create File Service

**Files:**
- Create: `Sources/NoteMac/Services/FileService.swift`
- Create: `Tests/NoteMacTests/FileServiceTests.swift`

**Step 1: Write failing tests for FileService**

Create `Tests/NoteMacTests/FileServiceTests.swift`:

```swift
import Testing
import Foundation
@testable import NoteMac

@Suite("FileService Tests")
struct FileServiceTests {
    @Test("Reads text file")
    func readsTextFile() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "Hello, World!".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let content = try await FileService.readFile(at: tempURL)

        #expect(content == "Hello, World!")
    }

    @Test("Writes text file")
    func writesTextFile() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-write.txt")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try await FileService.writeFile(content: "Test content", to: tempURL)

        let readBack = try String(contentsOf: tempURL, encoding: .utf8)
        #expect(readBack == "Test content")
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test --filter FileServiceTests
```

Expected: FAIL - FileService not found.

**Step 3: Implement FileService**

Create `Sources/NoteMac/Services/FileService.swift`:

```swift
import Foundation

enum FileServiceError: Error, LocalizedError {
    case fileNotFound(URL)
    case readFailed(URL, Error)
    case writeFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .readFailed(let url, let error):
            return "Failed to read \(url.lastPathComponent): \(error.localizedDescription)"
        case .writeFailed(let url, let error):
            return "Failed to write \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}

enum FileService {
    static func readFile(at url: URL) async throws -> String {
        try await Task.detached {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw FileServiceError.fileNotFound(url)
            }

            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch {
                throw FileServiceError.readFailed(url, error)
            }
        }.value
    }

    static func writeFile(content: String, to url: URL) async throws {
        try await Task.detached {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                throw FileServiceError.writeFailed(url, error)
            }
        }.value
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
swift test --filter FileServiceTests
```

Expected: All 2 tests PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add FileService for async file read/write"
```

---

### Task 9: Add Open/Save Commands to App

**Files:**
- Modify: `Sources/NoteMac/NoteMacApp.swift`
- Modify: `Sources/NoteMac/Models/AppState.swift`

**Step 1: Add file operation methods to AppState**

Modify `Sources/NoteMac/Models/AppState.swift`, add these methods:

```swift
// Add to AppState class:

    @MainActor
    func openFile(at url: URL) async throws {
        let content = try await FileService.readFile(at: url)

        // Check if already open
        if let existing = documents.first(where: { $0.filePath == url }) {
            activeDocumentID = existing.id
            return
        }

        let doc = Document(content: content, filePath: url)
        doc.markSaved() // Not modified since just opened
        documents.append(doc)
        activeDocumentID = doc.id
    }

    @MainActor
    func saveActiveDocument() async throws {
        guard let doc = activeDocument, let url = doc.filePath else { return }
        try await FileService.writeFile(content: doc.content, to: url)
        doc.markSaved()
    }

    @MainActor
    func saveActiveDocumentAs(to url: URL) async throws {
        guard let doc = activeDocument else { return }
        try await FileService.writeFile(content: doc.content, to: url)
        doc.filePath = url
        doc.markSaved()
    }
```

**Step 2: Update NoteMacApp with file commands**

Modify `Sources/NoteMac/NoteMacApp.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

@main
struct NoteMacApp: App {
    @State private var appState = AppState()
    @State private var isOpenPanelPresented = false
    @State private var isSavePanelPresented = false

    var body: some Scene {
        WindowGroup {
            MainWindow(appState: appState)
                .fileImporter(
                    isPresented: $isOpenPanelPresented,
                    allowedContentTypes: [.plainText, .init(filenameExtension: "md")!],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        Task {
                            try? await appState.openFile(at: url)
                        }
                    }
                }
                .fileExporter(
                    isPresented: $isSavePanelPresented,
                    document: TextDocument(content: appState.activeDocument?.content ?? ""),
                    contentType: appState.activeDocument?.isMarkdown == true ? .init(filenameExtension: "md")! : .plainText,
                    defaultFilename: appState.activeDocument?.title ?? "Untitled"
                ) { result in
                    if case .success(let url) = result {
                        Task {
                            try? await appState.saveActiveDocumentAs(to: url)
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    appState.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open...") {
                    isOpenPanelPresented = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    Task {
                        if appState.activeDocument?.filePath != nil {
                            try? await appState.saveActiveDocument()
                        } else {
                            isSavePanelPresented = true
                        }
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.activeDocument == nil)

                Button("Save As...") {
                    isSavePanelPresented = true
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.activeDocument == nil)
            }
        }
    }
}

// Helper for file exporter
struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            content = String(data: data, encoding: .utf8) ?? ""
        } else {
            content = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: content.data(using: .utf8) ?? Data())
    }
}
```

**Step 3: Verify it compiles**

```bash
swift build
```

Expected: Build succeeds.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add Open/Save/Save As file operations"
```

---

## Phase 4: Session Persistence

### Task 10: Create Session Store Service

**Files:**
- Create: `Sources/NoteMac/Services/SessionStore.swift`
- Create: `Tests/NoteMacTests/SessionStoreTests.swift`

**Step 1: Write failing tests for SessionStore**

Create `Tests/NoteMacTests/SessionStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import NoteMac

@Suite("SessionStore Tests")
struct SessionStoreTests {
    @Test("Saves and restores session")
    func savesAndRestoresSession() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = SessionStore(baseURL: tempDir)

        // Create test state
        let state = AppState()
        state.documents[0].content = "Test content"
        state.newDocument()
        state.fontSize = 15

        // Save
        try await store.save(state: state)

        // Restore
        let restored = try await store.restore()

        #expect(restored != nil)
        #expect(restored?.documents.count == 2)
        #expect(restored?.fontSize == 15)
    }
}
```

**Step 2: Run tests to verify they fail**

```bash
swift test --filter SessionStoreTests
```

Expected: FAIL - SessionStore not found.

**Step 3: Implement SessionStore**

Create `Sources/NoteMac/Services/SessionStore.swift`:

```swift
import Foundation

struct SessionData: Codable {
    struct DocumentData: Codable {
        let id: UUID
        let content: String
        let filePath: String?
        let cursorLine: Int
        let cursorColumn: Int
        let scrollPosition: CGFloat
    }

    let documents: [DocumentData]
    let activeDocumentID: UUID?
    let wordWrapEnabled: Bool
    let showLineNumbers: Bool
    let fontSize: CGFloat
}

actor SessionStore {
    private let baseURL: URL

    private var sessionFileURL: URL {
        baseURL.appendingPathComponent("session.json")
    }

    private var draftsURL: URL {
        baseURL.appendingPathComponent("drafts")
    }

    init(baseURL: URL? = nil) {
        if let baseURL {
            self.baseURL = baseURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseURL = appSupport.appendingPathComponent("NoteMac")
        }
    }

    func save(state: AppState) async throws {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: draftsURL, withIntermediateDirectories: true)

        // Save drafts (unsaved documents)
        for doc in state.documents where doc.filePath == nil && !doc.content.isEmpty {
            let draftURL = draftsURL.appendingPathComponent("\(doc.id.uuidString).txt")
            try doc.content.write(to: draftURL, atomically: true, encoding: .utf8)
        }

        // Save session metadata
        let sessionData = SessionData(
            documents: state.documents.map { doc in
                SessionData.DocumentData(
                    id: doc.id,
                    content: doc.filePath == nil ? "" : "", // Content saved in drafts for unsaved
                    filePath: doc.filePath?.path,
                    cursorLine: doc.cursorLine,
                    cursorColumn: doc.cursorColumn,
                    scrollPosition: doc.scrollPosition
                )
            },
            activeDocumentID: state.activeDocumentID,
            wordWrapEnabled: state.wordWrapEnabled,
            showLineNumbers: state.showLineNumbers,
            fontSize: state.fontSize
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(sessionData)
        try data.write(to: sessionFileURL)
    }

    func restore() async throws -> AppState? {
        guard FileManager.default.fileExists(atPath: sessionFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: sessionFileURL)
        let sessionData = try JSONDecoder().decode(SessionData.self, from: data)

        let state = AppState()
        state.documents.removeAll()
        state.wordWrapEnabled = sessionData.wordWrapEnabled
        state.showLineNumbers = sessionData.showLineNumbers
        state.fontSize = sessionData.fontSize

        for docData in sessionData.documents {
            var content = ""

            if let filePath = docData.filePath {
                // Load from file
                let url = URL(fileURLWithPath: filePath)
                if FileManager.default.fileExists(atPath: filePath) {
                    content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                }
            } else {
                // Load from drafts
                let draftURL = draftsURL.appendingPathComponent("\(docData.id.uuidString).txt")
                if FileManager.default.fileExists(atPath: draftURL.path) {
                    content = (try? String(contentsOf: draftURL, encoding: .utf8)) ?? ""
                }
            }

            let doc = Document(
                id: docData.id,
                content: content,
                filePath: docData.filePath.map { URL(fileURLWithPath: $0) }
            )
            doc.cursorLine = docData.cursorLine
            doc.cursorColumn = docData.cursorColumn
            doc.scrollPosition = docData.scrollPosition
            doc.markSaved()

            state.documents.append(doc)
        }

        if state.documents.isEmpty {
            state.newDocument()
        }

        state.activeDocumentID = sessionData.activeDocumentID ?? state.documents.first?.id

        return state
    }
}
```

**Step 4: Run tests to verify they pass**

```bash
swift test --filter SessionStoreTests
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add SessionStore for session persistence"
```

---

### Task 11: Integrate Session Persistence into App

**Files:**
- Modify: `Sources/NoteMac/NoteMacApp.swift`

**Step 1: Update NoteMacApp to save/restore session**

Modify `Sources/NoteMac/NoteMacApp.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

@main
struct NoteMacApp: App {
    @State private var appState = AppState()
    @State private var isOpenPanelPresented = false
    @State private var isSavePanelPresented = false

    private let sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            MainWindow(appState: appState)
                .task {
                    // Restore session on launch
                    if let restored = try? await sessionStore.restore() {
                        appState = restored
                    }
                }
                .onDisappear {
                    // Save session on close
                    Task {
                        try? await sessionStore.save(state: appState)
                    }
                }
                .fileImporter(
                    isPresented: $isOpenPanelPresented,
                    allowedContentTypes: [.plainText, .init(filenameExtension: "md")!],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        Task {
                            try? await appState.openFile(at: url)
                        }
                    }
                }
                .fileExporter(
                    isPresented: $isSavePanelPresented,
                    document: TextDocument(content: appState.activeDocument?.content ?? ""),
                    contentType: appState.activeDocument?.isMarkdown == true ? .init(filenameExtension: "md")! : .plainText,
                    defaultFilename: appState.activeDocument?.title ?? "Untitled"
                ) { result in
                    if case .success(let url) = result {
                        Task {
                            try? await appState.saveActiveDocumentAs(to: url)
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    appState.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open...") {
                    isOpenPanelPresented = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    Task {
                        if appState.activeDocument?.filePath != nil {
                            try? await appState.saveActiveDocument()
                        } else {
                            isSavePanelPresented = true
                        }
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.activeDocument == nil)

                Button("Save As...") {
                    isSavePanelPresented = true
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.activeDocument == nil)
            }

            CommandGroup(after: .windowArrangement) {
                Button("Close Tab") {
                    if let id = appState.activeDocumentID {
                        appState.closeDocument(id: id)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}

// Helper for file exporter
struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var content: String

    init(content: String) {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            content = String(data: data, encoding: .utf8) ?? ""
        } else {
            content = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: content.data(using: .utf8) ?? Data())
    }
}

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section("Editor") {
                Slider(value: $appState.fontSize, in: 10...24, step: 1) {
                    Text("Font Size: \(Int(appState.fontSize))pt")
                }

                Toggle("Word Wrap", isOn: $appState.wordWrapEnabled)

                Toggle("Show Line Numbers", isOn: $appState.showLineNumbers)
            }
        }
        .formStyle(.grouped)
        .frame(width: 350)
        .padding()
    }
}
```

**Step 2: Verify it compiles**

```bash
swift build
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: integrate session persistence and add Settings"
```

---

## Phase 5: Find & Replace

### Task 12: Add Find Bar View

**Files:**
- Create: `Sources/NoteMac/Views/FindBar.swift`
- Modify: `Sources/NoteMac/Views/MainWindow.swift`

**Step 1: Create FindBar view**

Create `Sources/NoteMac/Views/FindBar.swift`:

```swift
import SwiftUI

struct FindBar: View {
    @Binding var isVisible: Bool
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var showReplace: Bool

    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onReplace: () -> Void
    let onReplaceAll: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Find", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: 250)

                // Navigation buttons
                Button(action: onFindPrevious) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.bordered)
                .disabled(searchText.isEmpty)

                Button(action: onFindNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.bordered)
                .disabled(searchText.isEmpty)

                // Toggle replace
                Button(action: { showReplace.toggle() }) {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)

                Spacer()

                // Close
                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if showReplace {
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                            .foregroundStyle(.secondary)
                        TextField("Replace", text: $replaceText)
                            .textFieldStyle(.plain)
                    }
                    .padding(6)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: 250)

                    Button("Replace", action: onReplace)
                        .buttonStyle(.bordered)
                        .disabled(searchText.isEmpty)

                    Button("Replace All", action: onReplaceAll)
                        .buttonStyle(.bordered)
                        .disabled(searchText.isEmpty)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview {
    VStack {
        FindBar(
            isVisible: .constant(true),
            searchText: .constant("search"),
            replaceText: .constant(""),
            showReplace: .constant(true),
            onFindNext: {},
            onFindPrevious: {},
            onReplace: {},
            onReplaceAll: {}
        )
        Spacer()
    }
    .frame(width: 500, height: 200)
}
```

**Step 2: Add find state to AppState**

Add to `Sources/NoteMac/Models/AppState.swift`:

```swift
// Add these properties to AppState:
    var showFindBar: Bool = false
    var searchText: String = ""
    var replaceText: String = ""
    var showReplace: Bool = false
```

**Step 3: Integrate FindBar into MainWindow**

Modify `Sources/NoteMac/Views/MainWindow.swift`:

```swift
import SwiftUI

struct MainWindow: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBar(appState: appState)

            Divider()

            // Find bar (conditionally shown)
            if appState.showFindBar {
                FindBar(
                    isVisible: $appState.showFindBar,
                    searchText: $appState.searchText,
                    replaceText: $appState.replaceText,
                    showReplace: $appState.showReplace,
                    onFindNext: { /* TODO: Implement */ },
                    onFindPrevious: { /* TODO: Implement */ },
                    onReplace: { /* TODO: Implement */ },
                    onReplaceAll: { /* TODO: Implement */ }
                )
                Divider()
            }

            // Editor
            if let doc = appState.activeDocument {
                EditorView(
                    document: doc,
                    fontSize: appState.fontSize,
                    wordWrap: appState.wordWrapEnabled
                )
            } else {
                ContentUnavailableView(
                    "No Document",
                    systemImage: "doc.text",
                    description: Text("Press ⌘N to create a new document")
                )
            }

            Divider()

            // Status bar
            StatusBar(
                line: appState.activeDocument?.cursorLine ?? 1,
                column: appState.activeDocument?.cursorColumn ?? 1,
                encoding: "UTF-8",
                lineEnding: "LF",
                documentType: appState.activeDocument?.isMarkdown == true ? "Markdown" : "Plain Text"
            )
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}
```

**Step 4: Add Find menu commands**

Add to `Sources/NoteMac/NoteMacApp.swift` in the commands section:

```swift
// Add this CommandGroup:
            CommandGroup(after: .textEditing) {
                Button("Find...") {
                    appState.showFindBar = true
                    appState.showReplace = false
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find and Replace...") {
                    appState.showFindBar = true
                    appState.showReplace = true
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
            }
```

**Step 5: Verify it compiles**

```bash
swift build
```

Expected: Build succeeds.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add Find/Replace bar UI"
```

---

## Phase 6: View Commands

### Task 13: Add View Menu Commands

**Files:**
- Modify: `Sources/NoteMac/NoteMacApp.swift`

**Step 1: Add View menu commands for word wrap and line numbers**

Add to the commands section in `NoteMacApp.swift`:

```swift
// Add this CommandGroup:
            CommandMenu("View") {
                Toggle("Word Wrap", isOn: $appState.wordWrapEnabled)
                    .keyboardShortcut("w", modifiers: [.command, .option])

                Toggle("Show Line Numbers", isOn: $appState.showLineNumbers)
            }
```

**Step 2: Verify it compiles**

```bash
swift build
```

Expected: Build succeeds.

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: add View menu with word wrap and line numbers toggles"
```

---

## Phase 7: Final Polish

### Task 14: Run All Tests and Verify

**Step 1: Run full test suite**

```bash
swift test
```

Expected: All tests pass.

**Step 2: Build release**

```bash
swift build -c release
```

Expected: Release build succeeds.

**Step 3: Commit any final fixes**

```bash
git add -A
git commit -m "chore: finalize v1 implementation"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | 1-3 | Project setup, Document model, AppState model |
| 2 | 4-7 | EditorView, StatusBar, TabBar, MainWindow |
| 3 | 8-9 | FileService, Open/Save commands |
| 4 | 10-11 | SessionStore, session persistence integration |
| 5 | 12 | Find/Replace bar |
| 6 | 13 | View menu commands |
| 7 | 14 | Final testing and polish |

**Total: 14 tasks, ~50 steps**

---

## Future Tasks (Not in v1)

- Markdown syntax highlighting (MarkdownStyler)
- Cursor position tracking from STTextView
- File watching for external changes
- Liquid Glass refinements
- App icon design
