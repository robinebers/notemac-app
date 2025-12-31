import SwiftUI
import AppKit
import STTextView

// MARK: - Window Position Persistence

// Must match the key in NoteMacApp.swift AppDelegate
private let windowFrameKey = "NoteMacMainWindowFrame"

/// Saves the window frame to UserDefaults (must be called on main actor)
@MainActor
private func saveWindowFrame(_ window: NSWindow) {
    let frameString = NSStringFromRect(window.frame)
    UserDefaults.standard.set(frameString, forKey: windowFrameKey)
}

/// NSViewRepresentable that saves window position on move/resize
private struct WindowPositionSaver: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }

            // Observe window move/resize notifications to save frame
            NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: window,
                queue: .main
            ) { notification in
                guard let window = notification.object as? NSWindow else { return }
                MainActor.assumeIsolated {
                    saveWindowFrame(window)
                }
            }

            NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { notification in
                guard let window = notification.object as? NSWindow else { return }
                MainActor.assumeIsolated {
                    saveWindowFrame(window)
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Main Window View

struct MainWindow: View {
    @Bindable var appState: AppState
    @State private var textView: STTextView?

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { appState.sidebarVisible ? .all : .detailOnly },
            set: { appState.sidebarVisible = ($0 != .detailOnly) }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            // Sidebar (left column) - Finder-style document list
            Sidebar(appState: appState)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            // Main content area (right column)
            VStack(spacing: 0) {
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

                // Editor area
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
        }
        .navigationSplitViewStyle(.balanced)
        .background(WindowPositionSaver())
        .onAppear {
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
            // Store cursor position before replace
            let currentSelection = textView.selectedRange()
            // Replace the entire content
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textView.insertText(replacedString, replacementRange: fullRange)
            // Restore cursor position if still valid
            if currentSelection.location <= (textView.string as NSString).length {
                textView.setSelectedRange(NSRange(location: min(currentSelection.location, (textView.string as NSString).length), length: 0))
            }
        }
    }
}
