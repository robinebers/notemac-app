import AppKit
import Demark

@MainActor
final class PasteMarkdownConverter {
    private let demark: Demark
    private let options: DemarkOptions

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
                return markdown
            }
        }

        if let plain = pasteboard.string(forType: .string) {
            return plain
        }

        return nil
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
