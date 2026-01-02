import Testing
import Foundation
@testable import NoteMac

@Suite("Session Restoration Tests", .serialized)
struct SessionRestorationTests {

    // Helper to ensure clean state before each test
    func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("NoteMacTests")
            .appendingPathComponent(UUID().uuidString)
    }

    func cleanupSession(at baseURL: URL) {
        try? SessionStore.clearSession(in: baseURL)
        _ = try? FileManager.default.removeItem(at: baseURL)
    }

    @Test("Restores AppState from session data")
    func restoresAppStateFromSession() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        // Create and save a session
        let originalState = AppState()
        originalState.wordWrapEnabled = false
        originalState.showLineNumbers = true
        originalState.fontSize = 16

        let doc1 = Document(content: "First document")
        let doc2 = Document(content: "Second document")

        originalState.documents = [doc1, doc2]
        originalState.activeDocumentID = doc2.id

        try SessionStore.save(appState: originalState, in: storeURL)

        // Load session data
        guard let sessionData = try SessionStore.load(from: storeURL) else {
            Issue.record("Session data should not be nil")
            return
        }

        // Restore AppState
        let restoredState = AppState.restore(from: sessionData)

        // Verify preferences
        #expect(restoredState.wordWrapEnabled == false)
        #expect(restoredState.showLineNumbers == true)
        #expect(restoredState.fontSize == 16)

        // Verify documents
        #expect(restoredState.documents.count == 2)
        #expect(restoredState.activeDocumentID == doc2.id)

        let restoredDoc1 = restoredState.documents.first { $0.id == doc1.id }
        #expect(restoredDoc1?.content == "First document")

        let restoredDoc2 = restoredState.documents.first { $0.id == doc2.id }
        #expect(restoredDoc2?.content == "Second document")

        cleanupSession(at: storeURL)
    }

    @Test("Restores untitled documents with content")
    func restoresUntitledDocuments() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        // Create session with untitled document
        let originalState = AppState()
        let untitled = Document(content: "Unsaved work\nLine 2")
        untitled.cursorLine = 2
        untitled.cursorColumn = 5

        originalState.documents = [untitled]

        try SessionStore.save(appState: originalState, in: storeURL)

        // Load and restore
        guard let sessionData = try SessionStore.load(from: storeURL) else {
            Issue.record("Session data should not be nil")
            return
        }

        let restoredState = AppState.restore(from: sessionData)

        #expect(restoredState.documents.count == 1)

        let restoredDoc = restoredState.documents.first
        #expect(restoredDoc != nil)
        #expect(restoredDoc?.content == "Unsaved work\nLine 2")
        #expect(restoredDoc?.filePath == nil)
        #expect(restoredDoc?.cursorLine == 2)
        #expect(restoredDoc?.cursorColumn == 5)

        cleanupSession(at: storeURL)
    }

    @Test("Handles missing files gracefully")
    func handlesMissingFiles() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        // Create session with a file path that doesn't exist
        let originalState = AppState()
        let doc = Document(
            content: "Cached content",
            filePath: URL(fileURLWithPath: "/nonexistent/file.txt")
        )

        originalState.documents = [doc]

        try SessionStore.save(appState: originalState, in: storeURL)

        // Load and restore
        guard let sessionData = try SessionStore.load(from: storeURL) else {
            Issue.record("Session data should not be nil")
            return
        }

        let restoredState = AppState.restore(from: sessionData)

        #expect(restoredState.documents.count == 1)

        let restoredDoc = restoredState.documents.first
        #expect(restoredDoc != nil)
        // Should use cached content when file is missing
        #expect(restoredDoc?.content == "Cached content")
        // Should preserve the file path
        #expect(restoredDoc?.filePath?.path == "/nonexistent/file.txt")
        // Document should be marked as modified since content may be stale
        #expect(restoredDoc?.isModified == true)

        cleanupSession(at: storeURL)
    }

    @Test("Reloads existing files from disk")
    func reloadsExistingFiles() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test-\(UUID().uuidString).txt")

        let originalContent = "Original file content"
        try originalContent.write(to: testFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFile)
        }

        // Create session with this file (with old content)
        let originalState = AppState()
        let doc = Document(
            content: "Old cached content",
            filePath: testFile
        )

        originalState.documents = [doc]

        try SessionStore.save(appState: originalState, in: storeURL)

        // Load and restore - should reload from disk
        guard let sessionData = try SessionStore.load(from: storeURL) else {
            Issue.record("Session data should not be nil")
            return
        }

        let restoredState = AppState.restore(from: sessionData)

        #expect(restoredState.documents.count == 1)

        let restoredDoc = restoredState.documents.first
        #expect(restoredDoc != nil)
        // Should load fresh content from disk, not cached content
        #expect(restoredDoc?.content == "Original file content")
        #expect(restoredDoc?.filePath == testFile)
        // Should be marked as saved since we just loaded from disk
        #expect(restoredDoc?.isModified == false)

        cleanupSession(at: storeURL)
    }

    @Test("Preserves cursor position and scroll")
    func preservesCursorAndScroll() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        let originalState = AppState()
        let doc = Document(content: "Test content")
        doc.cursorLine = 10
        doc.cursorColumn = 25
        doc.scrollPosition = 150.0

        originalState.documents = [doc]

        try SessionStore.save(appState: originalState, in: storeURL)

        // Load and restore
        guard let sessionData = try SessionStore.load(from: storeURL) else {
            Issue.record("Session data should not be nil")
            return
        }

        let restoredState = AppState.restore(from: sessionData)

        let restoredDoc = restoredState.documents.first
        #expect(restoredDoc != nil)
        #expect(restoredDoc?.cursorLine == 10)
        #expect(restoredDoc?.cursorColumn == 25)
        #expect(restoredDoc?.scrollPosition == 150.0)

        cleanupSession(at: storeURL)
    }

    @Test("Preserves encoding and line ending settings")
    func preservesEncodingAndLineEnding() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        let originalState = AppState()
        let doc = Document(
            content: "Test",
            encoding: .utf16,
            encodingName: "UTF-16",
            lineEnding: .crlf
        )

        originalState.documents = [doc]

        try SessionStore.save(appState: originalState, in: storeURL)

        // Load and restore
        guard let sessionData = try SessionStore.load(from: storeURL) else {
            Issue.record("Session data should not be nil")
            return
        }

        let restoredState = AppState.restore(from: sessionData)

        let restoredDoc = restoredState.documents.first
        #expect(restoredDoc != nil)
        #expect(restoredDoc?.encoding == .utf16)
        #expect(restoredDoc?.encodingName == "UTF-16")
        #expect(restoredDoc?.lineEnding == .crlf)

        cleanupSession(at: storeURL)
    }

    @Test("Falls back to default state when session is empty")
    func fallsBackToDefaultWhenEmpty() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        // Create session with no documents (edge case)
        let sessionData = SessionData(
            documents: [],
            activeDocumentID: nil,
            wordWrapEnabled: true,
            showLineNumbers: false,
            fontSize: 12,
            sidebarVisible: true
        )

        let restoredState = AppState.restore(from: sessionData)

        // Should have one default document since we can't have zero documents
        #expect(restoredState.documents.count == 1)
        #expect(restoredState.documents.first?.content == "")
        #expect(restoredState.activeDocumentID != nil)
        // But preferences should still be restored
        #expect(restoredState.wordWrapEnabled == true)
        #expect(restoredState.showLineNumbers == false)
        #expect(restoredState.fontSize == 12)

        cleanupSession(at: storeURL)
    }

    @Test("Preserves active document selection")
    func preservesActiveDocumentSelection() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        let originalState = AppState()
        let doc1 = Document(content: "Doc 1")
        let doc2 = Document(content: "Doc 2")
        let doc3 = Document(content: "Doc 3")

        originalState.documents = [doc1, doc2, doc3]
        originalState.activeDocumentID = doc2.id

        try SessionStore.save(appState: originalState, in: storeURL)

        // Load and restore
        guard let sessionData = try SessionStore.load(from: storeURL) else {
            Issue.record("Session data should not be nil")
            return
        }

        let restoredState = AppState.restore(from: sessionData)

        // Active document should be doc2
        #expect(restoredState.activeDocumentID == doc2.id)
        #expect(restoredState.activeDocument?.content == "Doc 2")

        cleanupSession(at: storeURL)
    }

    @Test("Handles invalid active document ID gracefully")
    func handlesInvalidActiveDocumentID() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        let doc = Document(content: "Test")

        // Create session with invalid active ID
        let sessionData = SessionData(
            documents: [DocumentData(
                id: doc.id,
                content: doc.content,
                filePath: nil,
                cursorLine: 1,
                cursorColumn: 1,
                scrollPosition: 0,
                createdAt: Date(),
                lastModifiedAt: Date(),
                encodingRawValue: String.Encoding.utf8.rawValue,
                lineEndingRaw: LineEnding.lf.rawValue
            )],
            activeDocumentID: UUID(), // Invalid ID that doesn't match any document
            wordWrapEnabled: true,
            showLineNumbers: false,
            fontSize: 13,
            sidebarVisible: true
        )

        let restoredState = AppState.restore(from: sessionData)

        // Should fall back to first document
        #expect(restoredState.activeDocumentID == doc.id)
        #expect(restoredState.documents.count == 1)

        cleanupSession(at: storeURL)
    }
}
