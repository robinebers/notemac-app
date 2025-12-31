import SwiftUI

struct TabBar: View {
    @Bindable var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            // Tabs
            ForEach(appState.documents) { doc in
                TabButton(
                    title: doc.title,
                    isActive: doc.id == appState.activeDocumentID,
                    isModified: doc.isModified,
                    onSelect: {
                        appState.setActiveDocument(id: doc.id)
                    },
                    onClose: {
                        appState.closeDocument(id: doc.id)
                    }
                )
            }

            // New tab button
            Button(action: { appState.newDocument() }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

struct TabButton: View {
    let title: String
    let isActive: Bool
    let isModified: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            // Modified indicator or close button
            Group {
                if isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .buttonStyle(.plain)
                } else if isModified {
                    Circle()
                        .fill(.primary.opacity(0.5))
                        .frame(width: 6, height: 6)
                } else {
                    Color.clear
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 12)

            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
