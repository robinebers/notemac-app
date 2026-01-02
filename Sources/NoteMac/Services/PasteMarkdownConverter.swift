import AppKit
import Demark

@MainActor
final class PasteMarkdownConverter {
    private let demark: Demark
    private let options: DemarkOptions
    private static let formattingTagRegex = try? NSRegularExpression(
        pattern: "<\\s*(h[1-6]|strong|b|em|i|ul|ol|li|code|pre|blockquote|a|img|table|thead|tbody|tr|td|th|hr|del|s|strike|sup|sub)\\b",
        options: [.caseInsensitive]
    )
    private static let boldStyleRegex = try? NSRegularExpression(
        pattern: "font-weight\\s*:\\s*(bold|[5-9]00)",
        options: [.caseInsensitive]
    )
    private static let italicStyleRegex = try? NSRegularExpression(
        pattern: "font-style\\s*:\\s*italic",
        options: [.caseInsensitive]
    )
    private static let strikeStyleRegex = try? NSRegularExpression(
        pattern: "text-decoration(-line)?\\s*:\\s*line-through",
        options: [.caseInsensitive]
    )

    init(
        demark: Demark = Demark(),
        options: DemarkOptions = DemarkOptions(
            headingStyle: .atx,
            bulletListMarker: "-",
            codeBlockStyle: .fenced
        )
    ) {
        self.demark = demark
        self.options = options
    }

    func convertHTMLToMarkdown(_ html: String) async throws -> String {
        try await demark.convertToMarkdown(html, options: options)
    }

    func markdownString(from pasteboard: NSPasteboard) async -> String? {
        let plain = pasteboard.string(forType: .string)

        if let html = htmlString(from: pasteboard) {
            if let plain, !containsSupportedFormatting(in: html) {
                return plain
            }

            if let markdown = try? await convertHTMLToMarkdown(html),
               !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return markdown
            }
        }

        if let plain {
            return plain
        }

        return nil
    }

    private func containsSupportedFormatting(in html: String) -> Bool {
        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        if let regex = Self.formattingTagRegex,
           regex.firstMatch(in: html, options: [], range: range) != nil {
            return true
        }

        for regex in [Self.boldStyleRegex, Self.italicStyleRegex, Self.strikeStyleRegex] {
            if let regex, regex.firstMatch(in: html, options: [], range: range) != nil {
                return true
            }
        }

        return false
    }

    private func htmlString(from pasteboard: NSPasteboard) -> String? {
        if let html = pasteboard.string(forType: .html) {
            return html
        }

        if let rtfData = pasteboard.data(forType: .rtf) {
            return htmlString(fromRTFData: rtfData, documentType: .rtf)
        }

        if let rtfdData = pasteboard.data(forType: .rtfd) {
            return htmlString(fromRTFData: rtfdData, documentType: .rtfd)
        }

        return nil
    }

    private func htmlString(
        fromRTFData data: Data,
        documentType: NSAttributedString.DocumentType
    ) -> String? {
        let readOptions: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: documentType
        ]
        guard let attributed = try? NSAttributedString(
            data: data,
            options: readOptions,
            documentAttributes: nil
        ) else {
            return nil
        }

        let exportOptions: [NSAttributedString.DocumentAttributeKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html
        ]
        guard let htmlData = try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: exportOptions
        ) else {
            return nil
        }

        return String(data: htmlData, encoding: .utf8)
    }
}
