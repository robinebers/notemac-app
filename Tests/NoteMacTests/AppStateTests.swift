import Testing
import Foundation
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
    @MainActor
    func closesDocument() {
        let state = AppState()
        state.newDocument()
        let docToClose = state.documents.last!

        state.closeDocument(id: docToClose.id)

        #expect(!state.documents.contains { $0.id == docToClose.id })
    }

    @Test("Cannot close last document - creates new one")
    @MainActor
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

    @Test("Can reorder documents")
    func canReorderDocuments() {
        let state = AppState()
        let docA = Document(content: "A")
        let docB = Document(content: "B")
        let docC = Document(content: "C")

        state.documents = [docA, docB, docC]

        state.moveDocuments(from: IndexSet(integer: 0), to: 3)

        #expect(state.documents.map { $0.id } == [docB.id, docC.id, docA.id])
    }

    @Test("Default markdown filename appends .md when missing")
    func defaultMarkdownFilenameAddsMd() {
        #expect(AppState.defaultMarkdownFilename("Notes") == "Notes.md")
    }

    @Test("Default markdown filename keeps existing extension")
    func defaultMarkdownFilenameKeepsExtension() {
        #expect(AppState.defaultMarkdownFilename("Notes.txt") == "Notes.txt")
    }

    @Test("Default markdown filename trims whitespace")
    func defaultMarkdownFilenameTrimsWhitespace() {
        #expect(AppState.defaultMarkdownFilename("  Notes  ") == "Notes.md")
    }

    @Test("URL helper appends .md when missing")
    func urlHelperAppendsMarkdownExtension() {
        let url = URL(fileURLWithPath: "/tmp/Notes")
        #expect(AppState.urlByAppendingMarkdownExtensionIfNeeded(url).pathExtension == "md")
    }
}
