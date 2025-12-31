import SwiftUI

struct StatusBar: View {
    let line: Int
    let column: Int
    let encoding: String
    let lineEnding: String
    let documentType: String

    var body: some View {
        HStack(spacing: 16) {
            Text("Ln \(line), Col \(column)")
                .monospacedDigit()

            Spacer()

            Text(encoding)

            Text(lineEnding)

            Text(documentType)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
