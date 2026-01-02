import AppKit
import STTextView

class NoteMacTextView: STTextView {
    private var pasteConverter: any PasteConverting

    override init(frame frameRect: NSRect) {
        pasteConverter = PasteMarkdownConverter()
        super.init(frame: frameRect)
    }

    convenience init(frame frameRect: NSRect, pasteConverter: any PasteConverting) {
        self.init(frame: frameRect)
        self.pasteConverter = pasteConverter
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [
            .string,
            NSPasteboard.PasteboardType(rawValue: "NSStringPboardType")
        ]
    }

    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        let selection = selectedRange()
        guard selection.length > 0 else {
            return false
        }
        let source = string as NSString
        let selectedText = source.substring(with: selection)

        pboard.clearContents()
        pboard.setString(selectedText, forType: .string)
        return true
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        let replacementRange = selectedRange()

        Task { @MainActor in
            if let markdown = await pasteConverter.markdownString(from: pasteboard) {
                insertText(markdown, replacementRange: replacementRange)
            } else {
                pasteFallback(sender, replacementRange: replacementRange)
            }
        }
    }

    @MainActor
    func pasteFallback(_ sender: Any?, replacementRange: NSRange) {
        setSelectedRange(replacementRange)
        super.paste(sender)
    }
}
