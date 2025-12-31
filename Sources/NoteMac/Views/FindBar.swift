import SwiftUI

struct FindBar: View {
    @Binding var isVisible: Bool
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var showReplace: Bool

    var onFindNext: () -> Void
    var onFindPrevious: () -> Void
    var onReplace: () -> Void
    var onReplaceAll: () -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Main search row
            HStack(spacing: 8) {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                // Search field
                TextField("Find", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .frame(minWidth: 200)

                // Previous/Next buttons
                HStack(spacing: 4) {
                    Button(action: onFindPrevious) {
                        Image(systemName: "chevron.up")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.borderless)
                    .disabled(searchText.isEmpty)
                    .help("Find Previous (⌘⇧G)")

                    Button(action: onFindNext) {
                        Image(systemName: "chevron.down")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.borderless)
                    .disabled(searchText.isEmpty)
                    .help("Find Next (⌘G)")
                }

                // Toggle replace button
                Button(action: { showReplace.toggle() }) {
                    Image(systemName: showReplace ? "chevron.up" : "chevron.down")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .help(showReplace ? "Hide Replace" : "Show Replace")

                // Close button
                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .help("Close (Esc)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Replace row (conditional)
            if showReplace {
                HStack(spacing: 8) {
                    // Replace icon
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    // Replace field
                    TextField("Replace", text: $replaceText)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 200)

                    // Replace buttons
                    HStack(spacing: 4) {
                        Button("Replace") {
                            onReplace()
                        }
                        .buttonStyle(.borderless)
                        .disabled(searchText.isEmpty)

                        Button("Replace All") {
                            onReplaceAll()
                        }
                        .buttonStyle(.borderless)
                        .disabled(searchText.isEmpty)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            isVisible = false
            return .handled
        }
    }
}
