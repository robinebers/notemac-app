import AppKit
import STTextView

final class NoteMacTextView: STTextView {
    private let pasteConverter = PasteMarkdownConverter()

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [
            .string,
            NSPasteboard.PasteboardType(rawValue: "NSStringPboardType")
        ]
    }

    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        let selection = selectedRange()
        let source = string as NSString
        let selectedText = selection.length > 0 ? source.substring(with: selection) : ""

        pboard.clearContents()
        pboard.setString(selectedText, forType: .string)
        return true
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        Task { @MainActor in
            if let markdown = await pasteConverter.markdownString(from: pasteboard) {
                insertText(markdown, replacementRange: selectedRange())
            }
        }
    }
}
