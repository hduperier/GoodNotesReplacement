import SwiftUI

/// Lets the user move a flashcard set into the root library or one of the
/// existing folders. Mirrors `MoveNotebookView`.
@MainActor
struct MoveFlashcardSetView: View {
    let set: FlashcardSet
    let store: any DocumentStore
    let onMove: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(title: "Library (Root)", systemImage: "tray.full",
                        isCurrent: set.folder == nil) {
                        move(to: nil)
                    }
                }
                if !allFolders.isEmpty {
                    Section("Folders") {
                        ForEach(allFolders) { folder in
                            row(title: folder.name, systemImage: "folder",
                                isCurrent: set.folder?.id == folder.id) {
                                move(to: folder)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move “\(set.title)”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(title: String, systemImage: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark").foregroundStyle(.secondary)
                }
            }
        }
        .disabled(isCurrent)
    }

    private var allFolders: [Folder] {
        guard let mem = store as? InMemoryDocumentStore else { return [] }
        var result: [Folder] = []
        func walk(_ folders: [Folder]) {
            for f in folders.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                result.append(f)
                walk(f.subfolders)
            }
        }
        walk(mem.rootFolders)
        return result
    }

    private func move(to folder: Folder?) {
        try? store.moveFlashcardSet(set, into: folder)
        try? store.save()
        onMove()
        dismiss()
    }
}

#Preview {
    let store = InMemoryDocumentStore(seed: true)
    let set = store.rootFlashcardSets.first!
    return MoveFlashcardSetView(set: set, store: store) {}
}
