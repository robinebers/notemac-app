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
