import AppKit
import Testing
@testable import NoteMac

@Suite("Paste Markdown Converter")
struct PasteMarkdownConverterTests {
    @Test("Converts basic HTML to Markdown")
    @MainActor
    func convertsBasicHTML() async throws {
        let converter = PasteMarkdownConverter()
        let html = """
        <h1>Hello</h1>
        <p>This is <strong>bold</strong> and <em>italic</em>.</p>
        <ul><li>One</li></ul>
        """

        let markdown = try await converter.convertHTMLToMarkdown(html)

        #expect(markdown.contains("# Hello"))
        #expect(markdown.contains("**bold**"))
        #expect(markdown.contains("*italic*") || markdown.contains("_italic_"))
        #expect(markdown.contains("- One"))
    }

    @Test("Prefers plain text when HTML has no formatting")
    @MainActor
    func prefersPlainTextWhenHTMLIsPlain() async throws {
        let converter = PasteMarkdownConverter()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("TestPasteboard-\(UUID().uuidString)"))
        let plain = """
        Hey {{first_name}},
        You just did something most people never will.
        Most people will watch another tutorial. Read another blog post. Buy another tool they'll never use. They'll spend the next 12 months \"learning\" while shipping exactly nothing.
        Not you. You decided to actually build something.
        """
        let html = """
        <p>Hey {{first_name}},</p>
        <p>You just did something most people never will.</p>
        <p>Most people will watch another tutorial. Read another blog post. Buy another tool they'll never use. They'll spend the next 12 months &quot;learning&quot; while shipping exactly nothing.</p>
        <p>Not you. You decided to actually build something.</p>
        """

        pasteboard.clearContents()
        pasteboard.setString(plain, forType: .string)
        pasteboard.setString(html, forType: .html)

        let markdown = await converter.markdownString(from: pasteboard)

        #expect(markdown == plain)
    }
}
