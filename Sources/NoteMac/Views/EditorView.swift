import SwiftUI
import STTextViewUI

struct EditorView: View {
    @Bindable var document: Document
    let fontSize: CGFloat
    let wordWrap: Bool

    var body: some View {
        TextView(
            text: Binding(
                get: { AttributedString(document.content) },
                set: { document.content = String($0.characters) }
            ),
            options: wordWrap ? [.wrapLines, .highlightSelectedLine] : [.highlightSelectedLine],
            plugins: []
        )
        .textViewFont(.monospacedSystemFont(ofSize: fontSize, weight: .regular))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
