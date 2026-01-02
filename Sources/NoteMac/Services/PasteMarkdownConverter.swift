import AppKit
import Demark

@MainActor
final class PasteMarkdownConverter {
    private let demark: Demark
    private let options: DemarkOptions
    private static let placeholderRegex = try? NSRegularExpression(
        pattern: "\\{\\{[^\\}]*\\}\\}",
        options: []
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
        if let html = htmlString(from: pasteboard) {
            if let markdown = try? await convertHTMLToMarkdown(html),
               !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return unescapeTemplatePlaceholders(in: markdown)
            }
        }

        if let plain = pasteboard.string(forType: .string) {
            return plain
        }

        return nil
    }

    private func unescapeTemplatePlaceholders(in markdown: String) -> String {
        guard let regex = Self.placeholderRegex else {
            return markdown
        }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        let matches = regex.matches(in: markdown, options: [], range: range)
        if matches.isEmpty {
            return markdown
        }

        var result = markdown
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: markdown) else {
                continue
            }
            let segment = String(markdown[matchRange])
            let unescaped = segment.replacingOccurrences(of: "\\_", with: "_")
            result.replaceSubrange(matchRange, with: unescaped)
        }

        return result
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
