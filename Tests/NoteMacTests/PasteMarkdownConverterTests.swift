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
}
