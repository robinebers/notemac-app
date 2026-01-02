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

    @Test("Preserves underscore placeholders in pasted markdown")
    @MainActor
    func preservesPlaceholderUnderscores() async throws {
        let converter = PasteMarkdownConverter()
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("TestPasteboard-\(UUID().uuidString)"))
        let html = """
        <p>Hey {{first_name}},</p>
        <h2>Opus Isn't &quot;The Best&quot;</h2>
        <p><em>Alien Tech</em></p>
        """

        pasteboard.clearContents()
        pasteboard.setString(html, forType: .html)

        let markdown = await converter.markdownString(from: pasteboard)

        #expect(markdown?.contains("{{first_name}}") == true)
        #expect(markdown?.contains("{{first\\_name}}") == false)
    }
}
