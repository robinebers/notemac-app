import Foundation
import Observation
import AppKit
import UniformTypeIdentifiers

@Observable
final class AppState {
    var documents: [Document]
    var activeDocumentID: UUID?
    var wordWrapEnabled: Bool
    var showLineNumbers: Bool
    var fontSize: CGFloat

    // Find bar state
    var findBarVisible: Bool
    var searchText: String
    var replaceText: String
    var showReplaceField: Bool

    // Find actions - closures that will be set by MainWindow
    var findNextAction: (() -> Void)?
    var findPreviousAction: (() -> Void)?

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
        self.findBarVisible = false
        self.searchText = ""
        self.replaceText = ""
        self.showReplaceField = false
    }

    /// Restore AppState from SessionData
    /// Attempts to reload files from disk, falling back to stored content
    static func restore(from sessionData: SessionData) -> AppState {
        let appState = AppState()

        // Restore preferences first
        appState.wordWrapEnabled = sessionData.wordWrapEnabled
        appState.showLineNumbers = sessionData.showLineNumbers
        appState.fontSize = sessionData.fontSize

        // Convert DocumentData back to Document instances
        var restoredDocuments: [Document] = []

        for docData in sessionData.documents {
            let doc = restoreDocument(from: docData)
            restoredDocuments.append(doc)
        }

        // If we successfully restored documents, use them
        if !restoredDocuments.isEmpty {
            appState.documents = restoredDocuments

            // Restore active document ID if it still exists
            if let activeID = sessionData.activeDocumentID,
               restoredDocuments.contains(where: { $0.id == activeID }) {
                appState.activeDocumentID = activeID
            } else {
                appState.activeDocumentID = restoredDocuments.first?.id
            }
        }
        // Otherwise keep the default single empty document

        return appState
    }

    /// Restore a single document from DocumentData
    /// For files: attempt to reload from disk, fall back to stored content
    /// For untitled: restore from stored content
    private static func restoreDocument(from data: DocumentData) -> Document {
        // Reconstruct encoding from raw value
        let encoding = String.Encoding(rawValue: data.encodingRawValue)

        // Reconstruct line ending from raw value
        let lineEnding = LineEnding(rawValue: data.lineEndingRaw) ?? .lf

        // If this document has a file path, try to reload from disk
        if let pathString = data.filePath {
            let url = URL(fileURLWithPath: pathString)

            // Check if file still exists
            if FileManager.default.fileExists(atPath: pathString) {
                // Try to reload the file
                if let result = try? FileService.load(from: url) {
                    // File loaded successfully - use fresh content from disk
                    let doc = Document(
                        id: data.id,
                        content: result.content,
                        filePath: url,
                        encoding: result.encoding,
                        encodingName: result.encodingName,
                        lineEnding: result.lineEnding,
                        cursorLine: data.cursorLine,
                        cursorColumn: data.cursorColumn,
                        scrollPosition: data.scrollPosition,
                        createdAt: data.createdAt,
                        lastModifiedAt: data.lastModifiedAt
                    )
                    doc.markSaved() // Just loaded, so not modified
                    return doc
                }
            }

            // File missing or can't be read - use stored content
            // Keep the file path but mark as modified (content may be stale)
            let doc = Document(
                id: data.id,
                content: data.content,
                filePath: url,
                encoding: encoding,
                encodingName: nameForEncoding(encoding),
                lineEnding: lineEnding,
                cursorLine: data.cursorLine,
                cursorColumn: data.cursorColumn,
                scrollPosition: data.scrollPosition,
                createdAt: data.createdAt,
                lastModifiedAt: data.lastModifiedAt
            )
            // Mark as recovered since file is missing and content may be stale
            doc.markAsRecovered()
            return doc
        }

        // Untitled document - restore from stored content
        return Document(
            id: data.id,
            content: data.content,
            filePath: nil,
            encoding: encoding,
            encodingName: nameForEncoding(encoding),
            lineEnding: lineEnding,
            cursorLine: data.cursorLine,
            cursorColumn: data.cursorColumn,
            scrollPosition: data.scrollPosition,
            createdAt: data.createdAt,
            lastModifiedAt: data.lastModifiedAt
        )
    }

    /// Get human-readable name for encoding
    private static func nameForEncoding(_ encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf16: return "UTF-16"
        case .utf16BigEndian: return "UTF-16 BE"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .ascii: return "ASCII"
        case .isoLatin1: return "ISO Latin 1"
        default: return "Unknown"
        }
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

    // MARK: - File Operations

    /// Open one or more files using NSOpenPanel
    @MainActor
    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .plainText,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!
        ]

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.loadFiles(urls: panel.urls)
        }
    }

    /// Save the active document (or trigger Save As if untitled)
    @MainActor
    func saveActiveDocument() {
        guard let doc = activeDocument else { return }

        if let filePath = doc.filePath {
            // Document already has a path, save directly
            do {
                try FileService.save(content: doc.content, to: filePath)
                doc.markSaved()
            } catch {
                showError(message: "Failed to save file: \(error.localizedDescription)")
            }
        } else {
            // No path yet, trigger Save As
            saveActiveDocumentAs()
        }
    }

    /// Save the active document to a new location using NSSavePanel
    @MainActor
    func saveActiveDocumentAs() {
        guard let doc = activeDocument else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = doc.title
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            do {
                try FileService.save(content: doc.content, to: url)
                doc.filePath = url
                doc.markSaved()
            } catch {
                self?.showError(message: "Failed to save file: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helpers

    @MainActor
    private func loadFiles(urls: [URL]) {
        for url in urls {
            do {
                let result = try FileService.load(from: url)

                let doc = Document(
                    content: result.content,
                    filePath: url,
                    encoding: result.encoding,
                    encodingName: result.encodingName,
                    lineEnding: result.lineEnding
                )
                doc.markSaved() // Just loaded, so not modified

                documents.append(doc)
                activeDocumentID = doc.id
            } catch {
                showError(message: "Failed to open \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
