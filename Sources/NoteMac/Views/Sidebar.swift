import SwiftUI
import UniformTypeIdentifiers

struct Sidebar: View {
    @Bindable var appState: AppState
    @State private var draggedDocumentID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Document list with native sidebar styling
            List {
                ForEach(appState.documents) { doc in
                    SidebarRow(
                        document: doc,
                        isActive: doc.id == appState.activeDocumentID,
                        onSelect: {
                            appState.setActiveDocument(id: doc.id)
                        },
                        onClose: {
                            appState.closeDocument(id: doc.id)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                    .listRowSeparator(.hidden)
                    .onDrag {
                        draggedDocumentID = doc.id
                        return NSItemProvider(object: doc.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: SidebarDropDelegate(
                            targetDocument: doc,
                            appState: appState,
                            draggedDocumentID: $draggedDocumentID
                        )
                    )
                }
            }
            .listStyle(.sidebar)

            Divider()

            // New Document button at bottom
            Button(action: { appState.newDocument() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("New Document")
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}

struct SidebarRow: View {
    let document: Document
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false
    @State private var isHoveringIndicator = false

    var body: some View {
        HStack(spacing: 8) {
            // Document type icon
            Image(systemName: document.isMarkdown ? "doc.text" : "doc")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            // Document title
            Text(document.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // VS Code-style indicator/close button
            // - Modified AND not hovering indicator → filled circle
            // - Otherwise → X button (close)
            Group {
                if document.isModified && !isHoveringIndicator {
                    Circle()
                        .fill(.primary.opacity(0.6))
                        .frame(width: 8, height: 8)
                } else {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHoveringIndicator = hovering
            }
            .opacity(isHovering || document.isModified ? 1 : 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
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

private struct SidebarDropDelegate: DropDelegate {
    let targetDocument: Document
    let appState: AppState
    @Binding var draggedDocumentID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggedDocumentID else { return }
        guard let fromIndex = appState.documents.firstIndex(where: { $0.id == draggedDocumentID }) else { return }
        guard let toIndex = appState.documents.firstIndex(where: { $0.id == targetDocument.id }) else { return }
        guard fromIndex != toIndex else { return }

        withAnimation {
            appState.moveDocuments(
                from: IndexSet(integer: fromIndex),
                to: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedDocumentID = nil
        return true
    }
}
