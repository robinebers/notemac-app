import SwiftUI
import AppKit
import STTextView

struct MainWindow: View {
    @Bindable var appState: AppState
    @State private var textView: STTextView?

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar with liquid glass effect
            TabBar(appState: appState)

            // Find bar (conditionally visible)
            if appState.findBarVisible {
                FindBar(
                    isVisible: $appState.findBarVisible,
                    searchText: $appState.searchText,
                    replaceText: $appState.replaceText,
                    showReplace: $appState.showReplaceField,
                    onFindNext: { performFind(next: true) },
                    onFindPrevious: { performFind(next: false) },
                    onReplace: { performReplace() },
                    onReplaceAll: { performReplaceAll() }
                )
            }

            // Editor area - solid content for readability
            if let activeDoc = appState.activeDocument {
                EditorView(
                    document: activeDoc,
                    fontSize: appState.fontSize,
                    wordWrap: appState.wordWrapEnabled,
                    showLineNumbers: appState.showLineNumbers,
                    onTextViewReady: { view in
                        textView = view
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Fallback for no active document (should not happen)
                Text("No document available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Status bar
            StatusBar(
                line: appState.activeDocument?.cursorLine ?? 1,
                column: appState.activeDocument?.cursorColumn ?? 1,
                encoding: appState.activeDocument?.encodingName ?? "UTF-8",
                lineEnding: appState.activeDocument?.lineEnding.displayName ?? "LF",
                documentType: appState.activeDocument?.isMarkdown == true ? "Markdown" : "Plain Text"
            )
        }
        .onAppear {
            // Set up find action closures
            appState.findNextAction = { performFind(next: true) }
            appState.findPreviousAction = { performFind(next: false) }
        }
    }

    private func performFind(next: Bool) {
        guard let textView, !appState.searchText.isEmpty else { return }

        let searchText = appState.searchText
        let currentString = textView.string as NSString
        let currentRange = textView.selectedRange()

        var searchRange: NSRange
        if next {
            // Search from current position to end
            searchRange = NSRange(
                location: currentRange.location + currentRange.length,
                length: currentString.length - (currentRange.location + currentRange.length)
            )
        } else {
            // Search from beginning to current position
            searchRange = NSRange(location: 0, length: currentRange.location)
        }

        let foundRange = currentString.range(of: searchText, options: next ? [] : .backwards, range: searchRange)

        if foundRange.location != NSNotFound {
            textView.setSelectedRange(foundRange)
            textView.scrollRangeToVisible(foundRange)
        } else {
            // Wrap around - search entire document
            let wrappedRange = currentString.range(of: searchText, options: next ? [] : .backwards)
            if wrappedRange.location != NSNotFound {
                textView.setSelectedRange(wrappedRange)
                textView.scrollRangeToVisible(wrappedRange)
            }
        }
    }

    private func performReplace() {
        guard let textView, !appState.searchText.isEmpty else { return }

        let selectedRange = textView.selectedRange()
        let selectedText = (textView.string as NSString).substring(with: selectedRange)

        // Only replace if the current selection matches the search text
        if selectedText == appState.searchText {
            textView.insertText(appState.replaceText, replacementRange: selectedRange)
            // Find next occurrence after replacing
            performFind(next: true)
        } else {
            // If current selection doesn't match, find first occurrence
            performFind(next: true)
        }
    }

    private func performReplaceAll() {
        guard let textView, !appState.searchText.isEmpty else { return }

        let currentString = textView.string
        let replacedString = currentString.replacingOccurrences(of: appState.searchText, with: appState.replaceText)

        if replacedString != currentString {
            // Replace the entire content
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.insertText(replacedString, replacementRange: fullRange)
        }
    }
}
