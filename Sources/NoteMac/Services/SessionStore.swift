import Foundation

// MARK: - Codable Models for Persistence

struct SessionData: Codable {
    let documents: [DocumentData]
    let activeDocumentID: UUID?
    let wordWrapEnabled: Bool
    let showLineNumbers: Bool
    let fontSize: CGFloat
    let sidebarVisible: Bool?  // Optional for backwards compatibility
}

struct DocumentData: Codable {
    let id: UUID
    let content: String
    let filePath: String?  // nil = untitled/scratch doc
    let cursorLine: Int
    let cursorColumn: Int
    let scrollPosition: CGFloat
    let createdAt: Date
    let lastModifiedAt: Date
    let encodingRawValue: UInt  // String.Encoding.rawValue
    let lineEndingRaw: String   // LineEnding.rawValue
}

// MARK: - Session Store

enum SessionStore {
    static let appSupportURL = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!.appendingPathComponent("NoteMac")

    private static func sessionURL(in baseURL: URL) -> URL {
        baseURL.appendingPathComponent("session.json")
    }

    private static func draftsURL(in baseURL: URL) -> URL {
        baseURL.appendingPathComponent("drafts")
    }

    /// Save the current app state to persistent storage
    static func save(appState: AppState) throws {
        try save(appState: appState, in: appSupportURL)
    }

    /// Save the current app state to persistent storage at a custom base URL
    static func save(appState: AppState, in baseURL: URL) throws {
        let sessionURL = sessionURL(in: baseURL)
        let draftsURL = draftsURL(in: baseURL)

        // Ensure directories exist
        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: draftsURL,
            withIntermediateDirectories: true
        )

        // Convert AppState to SessionData
        let documentData = appState.documents.map { doc in
            DocumentData(
                id: doc.id,
                content: doc.content,
                filePath: doc.filePath?.path,
                cursorLine: doc.cursorLine,
                cursorColumn: doc.cursorColumn,
                scrollPosition: doc.scrollPosition,
                createdAt: doc.createdAt,
                lastModifiedAt: doc.lastModifiedAt,
                encodingRawValue: doc.encoding.rawValue,
                lineEndingRaw: doc.lineEnding.rawValue
            )
        }

        let sessionData = SessionData(
            documents: documentData,
            activeDocumentID: appState.activeDocumentID,
            wordWrapEnabled: appState.wordWrapEnabled,
            showLineNumbers: appState.showLineNumbers,
            fontSize: appState.fontSize,
            sidebarVisible: appState.sidebarVisible
        )

        // Encode and write to file
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(sessionData)
        try data.write(to: sessionURL, options: .atomic)
    }

    /// Load the previous session state
    /// Returns nil if no session exists or if loading fails
    static func load() throws -> SessionData? {
        try load(from: appSupportURL)
    }

    /// Load the previous session state from a custom base URL
    /// Returns nil if no session exists or if loading fails
    static func load(from baseURL: URL) throws -> SessionData? {
        let sessionURL = sessionURL(in: baseURL)

        // If session file doesn't exist, return nil (not an error)
        guard FileManager.default.fileExists(atPath: sessionURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: sessionURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(SessionData.self, from: data)
    }

    /// Clear the session file and all drafts
    static func clearSession() throws {
        try clearSession(in: appSupportURL)
    }

    /// Clear the session file and all drafts from a custom base URL
    static func clearSession(in baseURL: URL) throws {
        let sessionURL = sessionURL(in: baseURL)
        let draftsURL = draftsURL(in: baseURL)
        let fm = FileManager.default

        // Remove session file if it exists
        do {
            try fm.removeItem(at: sessionURL)
        } catch CocoaError.fileNoSuchFile {
            // File was already removed or doesn't exist, which is fine
        } catch {
            // Ignore other errors since we're cleaning up
        }

        // Remove drafts directory if it exists
        // Use do-catch to handle race conditions where directory may be removed between check and removal
        if fm.fileExists(atPath: draftsURL.path) {
            do {
                try fm.removeItem(at: draftsURL)
            } catch CocoaError.fileNoSuchFile {
                // Directory was already removed, which is fine
            }
        }
    }
}
