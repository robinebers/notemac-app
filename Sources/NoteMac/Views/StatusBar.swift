import SwiftUI

struct StatusBar: View {
    let line: Int
    let column: Int
    let content: String
    let selectionRange: NSRange

    @State private var charCount: Int = 0
    @State private var wordCount: Int = 0
    @State private var debounceTask: Task<Void, Never>?
    private static let debounceMilliseconds: UInt64 = 300

    private var formattedCounts: String {
        TextStatisticsFormatter.format(
            counts: TextCounts(characters: charCount, words: wordCount)
        )
    }

    var body: some View {
        HStack(spacing: 16) {
            Text("Ln \(line), Col \(column)")
                .monospacedDigit()

            Spacer()

            Text(formattedCounts)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
        .onAppear {
            updateCounts(for: content, selectionRange: selectionRange)
        }
        .onChange(of: content) { _, newValue in
            scheduleUpdate(for: newValue, selectionRange: selectionRange)
        }
        .onChange(of: selectionRange) { _, newValue in
            scheduleUpdate(for: content, selectionRange: newValue)
        }
        .onDisappear {
            debounceTask?.cancel()
        }
    }

    @MainActor
    private func updateCounts(for text: String, selectionRange: NSRange) {
        let counts = TextStatistics.counts(in: text, selectionRange: selectionRange)
        charCount = counts.characters
        wordCount = counts.words
    }

    private func scheduleUpdate(for text: String, selectionRange: NSRange) {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(Self.debounceMilliseconds))
            } catch {
                return
            }
            updateCounts(for: text, selectionRange: selectionRange)
        }
    }
}
