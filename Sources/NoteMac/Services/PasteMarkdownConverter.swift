import AppKit
import Demark

@MainActor
protocol MarkdownConverting {
    func convertToMarkdown(_ html: String, options: DemarkOptions) async throws -> String
}

extension Demark: MarkdownConverting {}

@MainActor
protocol PasteConverting {
    func markdownString(from pasteboard: NSPasteboard) async -> String?
}

@MainActor
final class PasteMarkdownConverter {
    private let demark: any MarkdownConverting
    private let options: DemarkOptions
    private static let placeholderRegex = try? NSRegularExpression(
        pattern: "\\{\\{[^\\}]*\\}\\}",
        options: []
    )
    private static let bracketPlaceholderRegex = try? NSRegularExpression(
        pattern: #"\\\[[^\n]+\\\]"#,
        options: []
    )

    init(
        demark: any MarkdownConverting = Demark(),
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

    func unescapeTemplatePlaceholders(in markdown: String) -> String {
        var result = markdown

        if let regex = Self.placeholderRegex {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: result) else {
                    continue
                }
                let segment = String(result[matchRange])
                let unescaped = segment.replacingOccurrences(of: "\\_", with: "_")
                result.replaceSubrange(matchRange, with: unescaped)
            }
        }

        if let regex = Self.bracketPlaceholderRegex {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: result) else {
                    continue
                }
                let segment = String(result[matchRange])
                let unescaped = segment
                    .replacingOccurrences(of: "\\[", with: "[")
                    .replacingOccurrences(of: "\\]", with: "]")
                result.replaceSubrange(matchRange, with: unescaped)
            }
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

extension PasteMarkdownConverter: PasteConverting {}
