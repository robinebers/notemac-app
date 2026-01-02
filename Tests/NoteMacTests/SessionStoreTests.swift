import Testing
import Foundation
@testable import NoteMac

@Suite("SessionStore Tests", .serialized)
struct SessionStoreTests {

    // Helper to ensure clean state before each test
    func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("NoteMacTests")
            .appendingPathComponent(UUID().uuidString)
    }

    func cleanupSession(at baseURL: URL) {
        // Ignore errors during cleanup - files may not exist yet
        _ = try? SessionStore.clearSession(in: baseURL)
        _ = try? FileManager.default.removeItem(at: baseURL)
    }

    @Test("Saves and loads session data successfully")
    func saveAndLoadRoundTrip() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        // Create test AppState
        let appState = AppState()
        appState.wordWrapEnabled = false
        appState.showLineNumbers = true
        appState.fontSize = 14

        let doc1 = Document(content: "Hello World")
        doc1.cursorLine = 5
        doc1.cursorColumn = 10
        doc1.scrollPosition = 100.0

        let doc2 = Document(
            content: "Test content",
            filePath: URL(fileURLWithPath: "/test/file.txt")
        )

        appState.documents = [doc1, doc2]
        appState.activeDocumentID = doc2.id

        // Save session
        try SessionStore.save(appState: appState, in: storeURL)

        // Load session
        let loaded = try SessionStore.load(from: storeURL)

        #expect(loaded != nil)

        guard let sessionData = loaded else {
            Issue.record("Session data should not be nil")
            return
        }

        // Verify app-level settings
        #expect(sessionData.wordWrapEnabled == false)
        #expect(sessionData.showLineNumbers == true)
        #expect(sessionData.fontSize == 14)
        #expect(sessionData.activeDocumentID == doc2.id)

        // Verify documents
        #expect(sessionData.documents.count == 2)

        let loadedDoc1 = sessionData.documents.first { $0.id == doc1.id }
        #expect(loadedDoc1 != nil)
        #expect(loadedDoc1?.content == "Hello World")
        #expect(loadedDoc1?.cursorLine == 5)
        #expect(loadedDoc1?.cursorColumn == 10)
        #expect(loadedDoc1?.scrollPosition == 100.0)
        #expect(loadedDoc1?.filePath == nil)

        let loadedDoc2 = sessionData.documents.first { $0.id == doc2.id }
        #expect(loadedDoc2 != nil)
        #expect(loadedDoc2?.content == "Test content")
        #expect(loadedDoc2?.filePath == "/test/file.txt")

        // Cleanup
        try SessionStore.clearSession(in: storeURL)
    }

    @Test("Handles missing session file gracefully")
    func handlesMissingSessionFile() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        // Clear any existing session
        try SessionStore.clearSession(in: storeURL)

        // Try to load non-existent session
        let loaded = try SessionStore.load(from: storeURL)

        #expect(loaded == nil)
    }

    @Test("Persists untitled documents with full content")
    func persistsUntitledDocuments() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        let appState = AppState()

        // Create an untitled document with content
        // Note: We can't set cursor position directly in Document initializer,
        // so we test that the content is preserved correctly
        let untitled = Document(content: "Unsaved draft content\nLine 2\nLine 3")

        appState.documents = [untitled]
        appState.activeDocumentID = untitled.id

        // Save and load
        try SessionStore.save(appState: appState, in: storeURL)
        let loaded = try SessionStore.load(from: storeURL)

        #expect(loaded != nil)

        guard let sessionData = loaded else {
            Issue.record("Session data should not be nil")
            return
        }

        #expect(sessionData.documents.count == 1)

        let loadedDoc = sessionData.documents.first
        #expect(loadedDoc != nil)
        #expect(loadedDoc?.content == "Unsaved draft content\nLine 2\nLine 3")
        #expect(loadedDoc?.filePath == nil)

        // Cleanup
        try SessionStore.clearSession(in: storeURL)
    }

    @Test("Clears session successfully")
    func clearsSession() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        // Create and save a session
        let appState = AppState()
        try SessionStore.save(appState: appState, in: storeURL)

        // Verify it exists
        let loaded = try SessionStore.load(from: storeURL)
        #expect(loaded != nil)

        // Clear session
        try SessionStore.clearSession(in: storeURL)

        // Verify it's gone
        let reloaded = try SessionStore.load(from: storeURL)
        #expect(reloaded == nil)
    }

    @Test("Preserves document encoding and line endings")
    func preservesEncodingAndLineEndings() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        let appState = AppState()

        let doc = Document(
            content: "Test",
            encoding: .utf16,
            encodingName: "UTF-16",
            lineEnding: .crlf
        )

        appState.documents = [doc]

        // Save and load
        try SessionStore.save(appState: appState, in: storeURL)
        let loaded = try SessionStore.load(from: storeURL)

        #expect(loaded != nil)

        guard let sessionData = loaded else {
            Issue.record("Session data should not be nil")
            return
        }

        let loadedDoc = sessionData.documents.first
        #expect(loadedDoc != nil)
        #expect(loadedDoc?.encodingRawValue == String.Encoding.utf16.rawValue)
        #expect(loadedDoc?.lineEndingRaw == LineEnding.crlf.rawValue)

        // Cleanup
        try SessionStore.clearSession(in: storeURL)
    }

    @Test("Preserves document timestamps")
    func preservesTimestamps() throws {
        let storeURL = makeStoreURL()
        cleanupSession(at: storeURL)
        defer { cleanupSession(at: storeURL) }

        let appState = AppState()

        let doc = Document(content: "Test")
        let createdAt = doc.createdAt
        let lastModifiedAt = doc.lastModifiedAt

        appState.documents = [doc]

        // Save and load
        try SessionStore.save(appState: appState, in: storeURL)
        let loaded = try SessionStore.load(from: storeURL)

        #expect(loaded != nil)

        guard let sessionData = loaded else {
            Issue.record("Session data should not be nil")
            return
        }

        let loadedDoc = sessionData.documents.first
        #expect(loadedDoc != nil)

        // Timestamps should be preserved (within 1 second tolerance for encoding/decoding)
        let createdDiff = abs(loadedDoc!.createdAt.timeIntervalSince(createdAt))
        let modifiedDiff = abs(loadedDoc!.lastModifiedAt.timeIntervalSince(lastModifiedAt))

        #expect(createdDiff < 1.0)
        #expect(modifiedDiff < 1.0)

        // Cleanup
        try SessionStore.clearSession(in: storeURL)
    }
}
