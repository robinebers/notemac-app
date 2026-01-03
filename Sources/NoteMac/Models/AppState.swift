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
    var sidebarVisible: Bool

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
        self.sidebarVisible = true
        self.findBarVisible = false
        self.searchText = ""
        self.replaceText = ""
        self.showReplaceField = false
    }

    static func defaultMarkdownFilename(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled.md" }
        let url = URL(fileURLWithPath: trimmed)
        if url.pathExtension.isEmpty {
            return trimmed + ".md"
        }
        return trimmed
    }

    static func urlByAppendingMarkdownExtensionIfNeeded(_ url: URL) -> URL {
        if url.pathExtension.isEmpty {
            return url.appendingPathExtension("md")
        }
        return url
    }

    /// Restore AppState from SessionData
    /// Attempts to reload files from disk, falling back to stored content
    static func restore(from sessionData: SessionData) -> AppState {
        let appState = AppState()

        // Restore preferences first
        appState.wordWrapEnabled = sessionData.wordWrapEnabled
        appState.showLineNumbers = sessionData.showLineNumbers
        appState.fontSize = sessionData.fontSize
        appState.sidebarVisible = sessionData.sidebarVisible ?? true

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
        let doc = Document(
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
        // Untitled documents with content should show as modified since
        // they've never been saved to disk
        if !data.content.isEmpty {
            doc.markAsRecovered()
        }
        return doc
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

    /// Close a document, prompting to save if modified
    @MainActor
    func closeDocument(id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        let doc = documents[index]

        if doc.isModified {
            // Prompt user to save changes
            let alert = NSAlert()
            alert.messageText = "Do you want to save the changes you made to \(doc.title)?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()

            switch response {
            case .alertFirstButtonReturn: // Save
                if doc.filePath != nil {
                    // Save directly
                    do {
                        try FileService.save(content: doc.content, to: doc.filePath!)
                        doc.markSaved()
                    } catch {
                        showError(message: "Failed to save: \(error.localizedDescription)")
                        return // Don't close on save failure
                    }
                } else {
                    // Need Save As for untitled document
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.plainText]
                    panel.nameFieldStringValue = doc.title
                    panel.canCreateDirectories = true

                    let saveResponse = panel.runModal()
                    guard saveResponse == .OK, let url = panel.url else {
                        return // User cancelled Save As, don't close
                    }

                    do {
                        try FileService.save(content: doc.content, to: url)
                        doc.filePath = url
                        doc.markSaved()
                    } catch {
                        showError(message: "Failed to save: \(error.localizedDescription)")
                        return // Don't close on save failure
                    }
                }
                // Fall through to close after successful save

            case .alertSecondButtonReturn: // Don't Save
                break // Proceed to close without saving

            default: // Cancel
                return // Don't close
            }
        }

        performClose(at: index, id: id)
    }

    /// Force close without prompting (for internal use after save confirmation)
    private func performClose(at index: Int, id: UUID) {
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

    func moveDocuments(from source: IndexSet, to destination: Int) {
        documents.move(fromOffsets: source, toOffset: destination)
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
                // FileService always saves as UTF-8, update metadata to match
                doc.encoding = .utf8
                doc.encodingName = "UTF-8"
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
                // FileService always saves as UTF-8, update metadata to match
                doc.encoding = .utf8
                doc.encodingName = "UTF-8"
            } catch {
                self?.showError(message: "Failed to save file: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helpers

    @MainActor
    private func loadFiles(urls: [URL]) {
        for url in urls {
            // Check if file is already open
            if let existingDoc = documents.first(where: { $0.filePath == url }) {
                activeDocumentID = existingDoc.id
                continue
            }

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
