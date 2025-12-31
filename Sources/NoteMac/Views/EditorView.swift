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
        textView.delegate = context.coordinator

        // Add padding inside the editor for better readability
        // Use lineFragmentPadding for horizontal text inset (space from left/right edge)
        if let textContainer = textView.textLayoutManager.textContainer {
            textContainer.lineFragmentPadding = 20
        }
        // Use scroll view content insets for top/bottom padding
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)

        // Configure word wrap properly
        configureWordWrap(textView: textView, scrollView: scrollView, enabled: wordWrap)

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

        // Update word wrap if changed (note: widthTracksTextView has inverted semantics)
        let currentWrapState = !textView.widthTracksTextView
        if currentWrapState != wordWrap {
            configureWordWrap(textView: textView, scrollView: scrollView, enabled: wordWrap)
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

    /// Configure word wrap for the text view
    /// When enabled: text wraps at view edge, no horizontal scroll
    /// When disabled: text extends horizontally, horizontal scroll enabled
    ///
    /// Note: STTextView's `widthTracksTextView` has inverted semantics:
    /// - false = text constrained to view width (wrap)
    /// - true = text can extend beyond view (no wrap)
    private func configureWordWrap(textView: STTextView, scrollView: NSScrollView, enabled: Bool) {
        if enabled {
            // Word wrap ON: constrain text to view width
            textView.widthTracksTextView = false
            scrollView.hasHorizontalScroller = false
        } else {
            // Word wrap OFF: allow text to extend horizontally
            textView.widthTracksTextView = true
            scrollView.hasHorizontalScroller = true
        }
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

        nonisolated func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? STTextView else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateCursorPosition(from: textView)
            }
        }

        /// Calculate and update cursor line/column from text view selection
        private func updateCursorPosition(from textView: STTextView) {
            let string = textView.string as NSString
            let selectedRange = textView.selectedRange()
            let cursorLocation = selectedRange.location

            // Handle empty document or cursor at start
            guard cursorLocation > 0 else {
                document.cursorLine = 1
                document.cursorColumn = 1
                return
            }

            // Count newlines before cursor to get line number
            let textBeforeCursor = string.substring(to: cursorLocation)
            let lines = textBeforeCursor.components(separatedBy: .newlines)

            // Line is count of lines, column is position in last line (1-indexed)
            document.cursorLine = lines.count
            document.cursorColumn = (lines.last?.count ?? 0) + 1
        }
    }
}
