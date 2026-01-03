import SwiftUI

struct StatusBar: View {
    let line: Int
    let column: Int
    let content: String

    @State private var charCount: Int = 0
    @State private var wordCount: Int = 0
    @State private var debounceTask: Task<Void, Never>?

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
            updateCounts(for: content)
        }
        .onChange(of: content) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .milliseconds(1000))
                } catch {
                    return
                }
                updateCounts(for: newValue)
            }
        }
        .onDisappear {
            debounceTask?.cancel()
        }
    }

    @MainActor
    private func updateCounts(for text: String) {
        let counts = TextStatistics.counts(in: text)
        charCount = counts.characters
        wordCount = counts.words
    }
}
