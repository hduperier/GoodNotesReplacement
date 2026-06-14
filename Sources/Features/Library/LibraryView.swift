import SwiftUI
import SwiftData

/// The library shelf: folders and notebooks for one level of the hierarchy.
/// Root is shown when `folder == nil`. Folder drill-down pushes another
/// `LibraryView` onto the surrounding `NavigationStack`.
@MainActor
struct LibraryView: View {
    /// The folder whose contents are shown. `nil` = root library.
    let folder: Folder?

    @Environment(\.documentStore) private var store

    // Real-store reads use @Query (live, observed). The in-memory preview store
    // isn't a SwiftData source, so these return empty there and we fall back to
    // its arrays below. Whichever store is active, exactly one path is non-empty.
    @Query(filter: #Predicate<Folder> { $0.parent == nil }, sort: \Folder.sortIndex)
    private var queriedRootFolders: [Folder]
    @Query(filter: #Predicate<Notebook> { $0.folder == nil }, sort: \Notebook.sortIndex)
    private var queriedRootNotebooks: [Notebook]
    @Query(filter: #Predicate<FlashcardSet> { $0.folder == nil }, sort: \FlashcardSet.sortIndex)
    private var queriedRootFlashcardSets: [FlashcardSet]

    /// Bumped after every mutation so the in-memory store's plain arrays (which
    /// aren't `@Query`-observed) are re-read. Harmless no-op cost for the real
    /// store, whose `@Query` results update on their own.
    @State private var refreshToken = 0

    @State private var showingNewNotebook = false
    @State private var showingNewFolder = false
    @State private var showingNewFlashcardSet = false
    @State private var newFolderName = ""

    // Rename flow.
    @State private var renameTarget: RenameTarget?
    @State private var renameText = ""

    // Move flow.
    @State private var moveNotebookTarget: Notebook?
    @State private var moveFlashcardSetTarget: FlashcardSet?

    @State private var openedNotebook: Notebook?
    @State private var openedFlashcardSet: FlashcardSet?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 24)]

    var body: some View {
        ScrollView {
            let _ = refreshToken // re-evaluate body on mutation
            VStack(alignment: .leading, spacing: 28) {
                if !subfolders.isEmpty {
                    section(title: "Folders") {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(subfolders) { sub in
                                NavigationLink(value: sub) {
                                    FolderTile(folder: sub)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { folderMenu(sub) }
                            }
                        }
                    }
                }

                section(title: subfolders.isEmpty && flashcardSets.isEmpty ? nil : "Notebooks") {
                    if notebooks.isEmpty {
                        if flashcardSets.isEmpty { emptyState }
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(notebooks) { notebook in
                                Button {
                                    openedNotebook = notebook
                                } label: {
                                    NotebookCardView(notebook: notebook)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("library.notebook.\(notebook.id.uuidString)")
                                .contextMenu { notebookMenu(notebook) }
                            }
                        }
                    }
                }

                if !flashcardSets.isEmpty {
                    section(title: "Flashcard Sets") {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                            ForEach(flashcardSets) { set in
                                Button {
                                    openedFlashcardSet = set
                                } label: {
                                    FlashcardSetTileView(set: set)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("library.flashcardSet.\(set.id.uuidString)")
                                .contextMenu { flashcardSetMenu(set) }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(folder?.name ?? "Library")
        .navigationDestination(for: Folder.self) { sub in
            LibraryView(folder: sub)
        }
        .navigationDestination(item: $openedNotebook) { notebook in
            NotebookEditorView(notebook: notebook)
        }
        .navigationDestination(item: $openedFlashcardSet) { set in
            FlashcardSetEditorView(set: set)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    newFolderName = ""
                    showingNewFolder = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .accessibilityIdentifier("library.newFolderButton")

                Button {
                    showingNewFlashcardSet = true
                } label: {
                    Label("New Flashcard Set", systemImage: "rectangle.stack.badge.plus")
                }
                .accessibilityIdentifier("library.newFlashcardSetButton")

                Button {
                    showingNewNotebook = true
                } label: {
                    Label("New Notebook", systemImage: "plus")
                }
                .accessibilityIdentifier("library.newNotebookButton")
            }
        }
        .sheet(isPresented: $showingNewNotebook) {
            NewNotebookView(folder: folder) { title, template, coverHex in
                createNotebook(title: title, template: template, coverHex: coverHex)
            }
        }
        .sheet(isPresented: $showingNewFlashcardSet) {
            NewFlashcardSetView(folder: folder) { title, coverHex in
                createFlashcardSet(title: title, coverHex: coverHex)
            }
        }
        .alert("New Folder", isPresented: $showingNewFolder) {
            TextField("Folder name", text: $newFolderName)
                .accessibilityIdentifier("library.newFolderField")
            Button("Cancel", role: .cancel) {}
            Button("Create") { createFolder() }
        }
        .alert("Rename", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") { commitRename() }
        }
        .sheet(item: $moveNotebookTarget) { notebook in
            MoveNotebookView(notebook: notebook, store: store) {
                bump()
            }
        }
        .sheet(item: $moveFlashcardSetTarget) { set in
            MoveFlashcardSetView(set: set, store: store) {
                bump()
            }
        }
    }

    // MARK: - Reads

    private var subfolders: [Folder] {
        let list = folder?.subfolders ?? rootFolders
        return list.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var notebooks: [Notebook] {
        let list = folder?.notebooks ?? rootNotebooks
        return list.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var flashcardSets: [FlashcardSet] {
        let list = folder?.flashcardSets ?? rootFlashcardSets
        return list.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var rootFolders: [Folder] {
        if let mem = store as? InMemoryDocumentStore { return mem.rootFolders }
        return queriedRootFolders
    }

    private var rootNotebooks: [Notebook] {
        if let mem = store as? InMemoryDocumentStore { return mem.rootNotebooks }
        return queriedRootNotebooks
    }

    private var rootFlashcardSets: [FlashcardSet] {
        if let mem = store as? InMemoryDocumentStore { return mem.rootFlashcardSets }
        return queriedRootFlashcardSets
    }

    // MARK: - Sections / empty state

    @ViewBuilder
    private func section(title: String?, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.title3.weight(.semibold))
            }
            content()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Notebooks", systemImage: "books.vertical")
        } description: {
            Text("Tap + to create your first notebook.")
        } actions: {
            Button("New Notebook") { showingNewNotebook = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Context menus

    @ViewBuilder
    private func notebookMenu(_ notebook: Notebook) -> some View {
        Button { beginRename(.notebook(notebook)) } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button { duplicate(notebook) } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Button { moveNotebookTarget = notebook } label: {
            Label("Move…", systemImage: "folder")
        }
        Divider()
        Button(role: .destructive) { delete(notebook) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func flashcardSetMenu(_ set: FlashcardSet) -> some View {
        Button { beginRename(.flashcardSet(set)) } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button { duplicate(set) } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        Button { moveFlashcardSetTarget = set } label: {
            Label("Move…", systemImage: "folder")
        }
        Divider()
        Button(role: .destructive) { delete(set) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func folderMenu(_ sub: Folder) -> some View {
        Button { beginRename(.folder(sub)) } label: {
            Label("Rename", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) { delete(sub) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Mutations

    private func createNotebook(title: String, template: PaperTemplate, coverHex: String) {
        do {
            let nb = try store.createNotebook(title: title, in: folder, template: template)
            nb.coverColorHex = coverHex
            try store.save()
            bump()
            openedNotebook = nb
        } catch { /* surfaced via UI in a fuller build */ }
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        try? store.createFolder(name: name, parent: folder)
        try? store.save()
        bump()
    }

    private func createFlashcardSet(title: String, coverHex: String) {
        do {
            let set = try store.createFlashcardSet(title: title, in: folder)
            set.coverColorHex = coverHex
            try store.save()
            bump()
            openedFlashcardSet = set
        } catch { /* surfaced via UI in a fuller build */ }
    }

    private func duplicate(_ notebook: Notebook) {
        try? store.duplicateNotebook(notebook)
        try? store.save()
        bump()
    }

    private func duplicate(_ set: FlashcardSet) {
        try? store.duplicateFlashcardSet(set)
        try? store.save()
        bump()
    }

    private func delete(_ notebook: Notebook) {
        try? store.deleteNotebook(notebook)
        try? store.save()
        bump()
    }

    private func delete(_ set: FlashcardSet) {
        try? store.deleteFlashcardSet(set)
        try? store.save()
        bump()
    }

    private func delete(_ folder: Folder) {
        try? store.deleteFolder(folder)
        try? store.save()
        bump()
    }

    private func beginRename(_ target: RenameTarget) {
        renameText = target.currentName
        renameTarget = target
    }

    private func commitRename() {
        guard let target = renameTarget else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            switch target {
            case .notebook(let nb): try? store.renameNotebook(nb, to: name)
            case .folder(let f): try? store.renameFolder(f, to: name)
            case .flashcardSet(let s): try? store.renameFlashcardSet(s, to: name)
            }
            try? store.save()
            bump()
        }
        renameTarget = nil
    }

    private func bump() { refreshToken &+= 1 }

    // MARK: - Helpers

    private enum RenameTarget: Identifiable {
        case notebook(Notebook)
        case folder(Folder)
        case flashcardSet(FlashcardSet)

        var id: UUID {
            switch self {
            case .notebook(let n): n.id
            case .folder(let f): f.id
            case .flashcardSet(let s): s.id
            }
        }
        var currentName: String {
            switch self {
            case .notebook(let n): n.title
            case .folder(let f): f.name
            case .flashcardSet(let s): s.title
            }
        }
    }
}

/// A folder tile on the shelf.
private struct FolderTile: View {
    let folder: Folder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.12))
                .aspectRatio(1.2, contentMode: .fit)
                .overlay(
                    Image(systemName: "folder.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                )
            Text(folder.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text("^[\(folder.notebooks.count) notebook](inflect: true)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Library") {
    NavigationStack {
        LibraryView(folder: nil)
    }
    .documentStore(InMemoryDocumentStore(seed: true))
    // A container satisfies the @Query dependency; the in-memory store still
    // supplies the data shown in the preview.
    .modelContainer(try! AppSchema.previewContainer())
}
