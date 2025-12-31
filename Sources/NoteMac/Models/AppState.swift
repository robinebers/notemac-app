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
