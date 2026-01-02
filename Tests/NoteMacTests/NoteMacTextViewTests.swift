import AppKit
import Testing
@testable import NoteMac

@Suite("NoteMacTextView")
struct NoteMacTextViewTests {
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
}
