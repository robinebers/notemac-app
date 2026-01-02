import AppKit
import Testing
@testable import NoteMac

@Suite("NoteMacTextView")
struct NoteMacTextViewTests {
    @MainActor
    struct StubPasteConverter: PasteConverting {
        let delayNanoseconds: UInt64
        let markdown: String?

        func markdownString(from pasteboard: NSPasteboard) async -> String? {
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            return markdown
        }
    }

    @MainActor
    final class FallbackTrackingTextView: NoteMacTextView {
        var didFallback = false

        override func pasteFallback(_ sender: Any?, replacementRange: NSRange) {
            didFallback = true
        }
    }

    @MainActor
    final class InsertTrackingTextView: NoteMacTextView {
        var lastInsertedText: String?
        var lastReplacementRange: NSRange?

        override func insertText(_ insertString: Any, replacementRange: NSRange) {
            lastInsertedText = insertString as? String
            lastReplacementRange = replacementRange
        }
    }

    @Test("Writes plain text only")
    @MainActor
    func writesPlainTextOnly() {
        let textView = NoteMacTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        textView.string = "Hello **bold**"
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("NoteMacTextViewTests"))
        pasteboard.clearContents()

        let wrote = textView.writeSelection(to: pasteboard, types: [NSPasteboard.PasteboardType.string])

        #expect(wrote)
        let types = pasteboard.types ?? []
        let allowedTypes: Set<NSPasteboard.PasteboardType> = [
            .string,
            NSPasteboard.PasteboardType(rawValue: "NSStringPboardType")
        ]
        #expect(types.contains(.string))
        #expect(Set(types).isSubset(of: allowedTypes))
        #expect(pasteboard.string(forType: .string) == "Hello")
    }

    @Test("Does not clear clipboard when there is no selection")
    @MainActor
    func doesNotClearClipboardWithoutSelection() {
        let textView = NoteMacTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        textView.string = "Hello"
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("NoteMacTextViewTestsNoSelection"))
        pasteboard.clearContents()
        pasteboard.setString("Keep", forType: .string)

        let wrote = textView.writeSelection(to: pasteboard, types: [.string])

        #expect(wrote == false)
        #expect(pasteboard.string(forType: .string) == "Keep")
    }

    @Test("Falls back to default paste when converter returns nil")
    @MainActor
    func fallsBackWhenConverterReturnsNil() async {
        let converter = StubPasteConverter(delayNanoseconds: 0, markdown: nil)
        let textView = FallbackTrackingTextView(
            frame: NSRect(x: 0, y: 0, width: 100, height: 100),
            pasteConverter: converter
        )

        textView.string = "Hello"
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        textView.paste(nil)
        try? await Task.sleep(nanoseconds: 20_000_000)

        #expect(textView.didFallback)
    }

    @Test("Uses captured selection for async paste")
    @MainActor
    func usesCapturedSelectionForAsyncPaste() async {
        let converter = StubPasteConverter(delayNanoseconds: 50_000_000, markdown: "X")
        let textView = InsertTrackingTextView(
            frame: NSRect(x: 0, y: 0, width: 100, height: 100),
            pasteConverter: converter
        )
        textView.string = "ABCDEF"
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        textView.paste(nil)
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        for _ in 0..<25 {
            if textView.lastInsertedText != nil {
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(textView.lastInsertedText == "X")
        #expect(textView.lastReplacementRange == NSRange(location: 0, length: 0))
    }

    @Test("Clamps replacement range when content changes during async paste")
    @MainActor
    func clampsReplacementRangeWhenContentChangesDuringAsyncPaste() async {
        let converter = StubPasteConverter(delayNanoseconds: 50_000_000, markdown: "X")
        let textView = InsertTrackingTextView(
            frame: NSRect(x: 0, y: 0, width: 100, height: 100),
            pasteConverter: converter
        )
        textView.string = "ABCDEFG"
        textView.setSelectedRange(NSRange(location: 6, length: 0))

        textView.paste(nil)
        textView.string = "AB"
        for _ in 0..<25 {
            if textView.lastInsertedText != nil {
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(textView.lastInsertedText == "X")
        #expect(textView.lastReplacementRange == NSRange(location: 2, length: 0))
    }
}
