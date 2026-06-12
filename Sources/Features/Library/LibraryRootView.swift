import SwiftUI
import SwiftData

/// iPad-class shell for the library. A sidebar lists the root library plus
/// top-level folders; the detail column hosts the shelf for the selected
/// destination inside its own `NavigationStack` (which pushes into subfolders
/// and the notebook editor).
@MainActor
public struct LibraryRootView: View {
    @Environment(\.documentStore) private var store

    @Query(filter: #Predicate<Folder> { $0.parent == nil }, sort: \Folder.sortIndex)
    private var queriedRootFolders: [Folder]

    @State private var selection: SidebarItem? = .library
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var refreshToken = 0

    @State private var showingNewFolder = false
    @State private var newFolderName = ""

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            let _ = refreshToken
            Label("Library", systemImage: "books.vertical")
                .tag(SidebarItem.library)

            if !rootFolders.isEmpty {
                Section("Folders") {
                    ForEach(rootFolders) { folder in
                        Label(folder.name, systemImage: "folder")
                            .tag(SidebarItem.folder(folder.id))
                    }
                }
            }
        }
        .navigationTitle("Notebooks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newFolderName = ""
                    showingNewFolder = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .accessibilityIdentifier("sidebar.newFolderButton")
            }
        }
        .alert("New Folder", isPresented: $showingNewFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                try? store.createFolder(name: name, parent: nil)
                try? store.save()
                refreshToken &+= 1
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        NavigationStack {
            switch selection {
            case .library, .none:
                LibraryView(folder: nil)
            case .folder(let id):
                if let folder = rootFolders.first(where: { $0.id == id }) {
                    LibraryView(folder: folder)
                } else {
                    LibraryView(folder: nil)
                }
            }
        }
        .id(selection) // rebuild the stack when switching sidebar destinations
    }

    private var rootFolders: [Folder] {
        if let mem = store as? InMemoryDocumentStore {
            return mem.rootFolders.sorted { $0.sortIndex < $1.sortIndex }
        }
        return queriedRootFolders
    }

    private enum SidebarItem: Hashable {
        case library
        case folder(UUID)
    }
}

#Preview {
    LibraryRootView()
        .documentStore(InMemoryDocumentStore(seed: true))
        .modelContainer(try! AppSchema.previewContainer())
}
