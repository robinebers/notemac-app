import SwiftUI
import STTextViewUI
import STTextView
import AppKit

struct EditorView: View {
    @Bindable var document: Document
    let fontSize: CGFloat
    let wordWrap: Bool
    let showLineNumbers: Bool

    // Callback to provide access to the underlying text view
    var onTextViewReady: ((STTextView) -> Void)?

    var body: some View {
        EditorViewRepresentable(
            document: document,
            fontSize: fontSize,
            wordWrap: wordWrap,
            showLineNumbers: showLineNumbers,
            onTextViewReady: onTextViewReady
        )
    }
}

private struct EditorViewRepresentable: NSViewRepresentable {
    @Bindable var document: Document
    let fontSize: CGFloat
    let wordWrap: Bool
    let showLineNumbers: Bool
    var onTextViewReady: ((STTextView) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = STTextView.scrollableTextView()
        let textView = scrollView.documentView as! STTextView

        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.highlightSelectedLine = true
        textView.widthTracksTextView = wordWrap
        textView.delegate = context.coordinator

        // Set up line numbers
        if showLineNumbers {
            let rulerView = STLineNumberRulerView(textView: textView)
            rulerView.font = .monospacedSystemFont(ofSize: 0, weight: .regular)
            rulerView.highlightSelectedLine = true
            scrollView.verticalRulerView = rulerView
            scrollView.rulersVisible = true
        }

        // Set initial content
        context.coordinator.isUpdating = true
        textView.setAttributedString(NSAttributedString(string: document.content))
        context.coordinator.isUpdating = false

        // Provide access to text view
        if let onTextViewReady {
            onTextViewReady(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! STTextView

        // CRITICAL: Update coordinator's document reference when switching tabs
        // Without this, text changes go to the wrong document
        let documentChanged = context.coordinator.document.id != document.id
        if documentChanged {
            context.coordinator.document = document
        }

        // Update content if changed externally or document switched
        context.coordinator.isUpdating = true
        if !context.coordinator.isDidChangeText || documentChanged {
            let currentContent = textView.string
            if currentContent != document.content {
                textView.setAttributedString(NSAttributedString(string: document.content))
            }
        }
        context.coordinator.isUpdating = false
        context.coordinator.isDidChangeText = false

        // Update font if changed
        if textView.font != .monospacedSystemFont(ofSize: fontSize, weight: .regular) {
            textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }

        // Update word wrap if changed
        if textView.widthTracksTextView != wordWrap {
            textView.widthTracksTextView = wordWrap
        }

        // Update line numbers if changed
        let hasLineNumbers = scrollView.verticalRulerView != nil
        if showLineNumbers != hasLineNumbers {
            if showLineNumbers {
                let rulerView = STLineNumberRulerView(textView: textView)
                rulerView.font = .monospacedSystemFont(ofSize: 0, weight: .regular)
                rulerView.highlightSelectedLine = true
                scrollView.verticalRulerView = rulerView
                scrollView.rulersVisible = true
            } else {
                scrollView.verticalRulerView = nil
                scrollView.rulersVisible = false
            }
        }
    }

    func makeCoordinator() -> EditorCoordinator {
        EditorCoordinator(document: document)
    }

    @MainActor
    class EditorCoordinator: NSObject, STTextViewDelegate {
        @Bindable var document: Document
        var isUpdating: Bool = false
        var isDidChangeText: Bool = false

        init(document: Document) {
            self.document = document
        }

        nonisolated func textViewDidChangeText(_ notification: Notification) {
            guard let textView = notification.object as? STTextView else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self, !self.isUpdating else { return }
                self.isDidChangeText = true
                self.document.content = textView.string
            }
        }
    }
}
