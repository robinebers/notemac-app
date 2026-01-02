import Testing
import Foundation
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

    @Test("Treats all documents as markdown")
    func detectsMarkdown() {
        let untitledDoc = Document()
        #expect(untitledDoc.isMarkdown == true)

        let txtDoc = Document()
        txtDoc.filePath = URL(fileURLWithPath: "/test.txt")
        #expect(txtDoc.isMarkdown == true)

        let mdDoc = Document()
        mdDoc.filePath = URL(fileURLWithPath: "/test.md")
        #expect(mdDoc.isMarkdown == true)
    }

    @Test("markAsRecovered marks document as modified")
    func markAsRecoveredWorks() {
        // Test with non-empty content
        let doc = Document(content: "Hello")
        doc.markSaved()
        #expect(doc.isModified == false)
        doc.markAsRecovered()
        #expect(doc.isModified == true)
    }

    @Test("markAsRecovered works with empty content")
    func markAsRecoveredWorksWithEmptyContent() {
        // Test with empty content - previously this would fail
        let doc = Document(content: "")
        doc.markSaved()
        #expect(doc.isModified == false)
        doc.markAsRecovered()
        #expect(doc.isModified == true)
    }

    @Test("markSaved clears recovered state")
    func markSavedClearsRecoveredState() {
        let doc = Document(content: "Hello")
        doc.markAsRecovered()
        #expect(doc.isModified == true)
        doc.markSaved()
        #expect(doc.isModified == false)
    }
}
