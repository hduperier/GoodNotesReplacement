import Foundation
import SwiftData

/// A non-persistent `DocumentStore` for SwiftUI previews and unit tests. Holds
/// model objects in plain arrays — no `ModelContainer` required. Behavior mirrors
/// the contract described in `DocumentStore` so tests written against this also
/// hold for `SwiftDataDocumentStore`.
@MainActor
public final class InMemoryDocumentStore: DocumentStore {

    public private(set) var rootFolders: [Folder] = []
    public private(set) var rootNotebooks: [Notebook] = []

    public init(seed: Bool = false) {
        if seed { seedSample() }
    }

    public static var schema: Schema { AppSchema.schema }

    // MARK: Folders

    @discardableResult
    public func createFolder(name: String, parent: Folder?) throws -> Folder {
        let siblings = parent?.subfolders ?? rootFolders
        let folder = Folder(name: name, parent: parent, sortIndex: siblings.count)
        if let parent {
            parent.subfolders.append(folder)
            touch(parent)
        } else {
            rootFolders.append(folder)
        }
        return folder
    }

    public func renameFolder(_ folder: Folder, to name: String) throws {
        folder.name = name
        touch(folder)
    }

    public func deleteFolder(_ folder: Folder) throws {
        if let parent = folder.parent {
            parent.subfolders.removeAll { $0.id == folder.id }
        } else {
            rootFolders.removeAll { $0.id == folder.id }
        }
    }

    public func moveFolder(_ folder: Folder, into parent: Folder?) throws {
        if folder.id == parent?.id { return }
        try deleteFolder(folder)
        folder.parent = parent
        if let parent {
            folder.sortIndex = parent.subfolders.count
            parent.subfolders.append(folder)
        } else {
            folder.sortIndex = rootFolders.count
            rootFolders.append(folder)
        }
        touch(folder)
    }

    // MARK: Notebooks

    @discardableResult
    public func createNotebook(title: String, in folder: Folder?, template: PaperTemplate) throws -> Notebook {
        let count = (folder?.notebooks ?? rootNotebooks).count
        let notebook = Notebook(title: title, folder: folder, defaultTemplate: template, sortIndex: count)
        let firstPage = Page(index: 0, template: template, notebook: notebook)
        notebook.pages.append(firstPage)
        if let folder {
            folder.notebooks.append(notebook)
            touch(folder)
        } else {
            rootNotebooks.append(notebook)
        }
        return notebook
    }

    public func renameNotebook(_ notebook: Notebook, to title: String) throws {
        notebook.title = title
        touch(notebook)
    }

    public func deleteNotebook(_ notebook: Notebook) throws {
        if let folder = notebook.folder {
            folder.notebooks.removeAll { $0.id == notebook.id }
        } else {
            rootNotebooks.removeAll { $0.id == notebook.id }
        }
    }

    public func moveNotebook(_ notebook: Notebook, into folder: Folder?) throws {
        try deleteNotebook(notebook)
        notebook.folder = folder
        if let folder {
            notebook.sortIndex = folder.notebooks.count
            folder.notebooks.append(notebook)
        } else {
            notebook.sortIndex = rootNotebooks.count
            rootNotebooks.append(notebook)
        }
        touch(notebook)
    }

    @discardableResult
    public func duplicateNotebook(_ notebook: Notebook) throws -> Notebook {
        let copy = Notebook(
            title: notebook.title + " copy",
            folder: notebook.folder,
            defaultTemplate: notebook.defaultTemplate,
            coverColorHex: notebook.coverColorHex,
            sortIndex: notebook.sortIndex + 1
        )
        for page in notebook.orderedPages {
            let p = Page(index: page.index, template: page.template, notebook: copy)
            p.drawingData = page.drawingData
            p.thumbnailData = page.thumbnailData
            copy.pages.append(p)
        }
        if let folder = notebook.folder {
            folder.notebooks.append(copy)
        } else {
            rootNotebooks.append(copy)
        }
        return copy
    }

    // MARK: Pages

    @discardableResult
    public func addPage(to notebook: Notebook, after page: Page?, template: PaperTemplate) throws -> Page {
        let insertIndex = (page?.index).map { $0 + 1 } ?? notebook.pages.count
        for p in notebook.pages where p.index >= insertIndex { p.index += 1 }
        let newPage = Page(index: insertIndex, template: template, notebook: notebook)
        notebook.pages.append(newPage)
        touch(notebook)
        return newPage
    }

    public func deletePage(_ page: Page) throws {
        guard let notebook = page.notebook else { throw DocumentStoreError.notFound }
        notebook.pages.removeAll { $0.id == page.id }
        for p in notebook.pages where p.index > page.index { p.index -= 1 }
        touch(notebook)
    }

    public func movePage(_ page: Page, to index: Int) throws {
        guard let notebook = page.notebook else { throw DocumentStoreError.notFound }
        var ordered = notebook.orderedPages
        guard index >= 0, index < ordered.count else { throw DocumentStoreError.invalidIndex }
        ordered.removeAll { $0.id == page.id }
        ordered.insert(page, at: index)
        for (i, p) in ordered.enumerated() { p.index = i }
        touch(notebook)
    }

    @discardableResult
    public func duplicatePage(_ page: Page) throws -> Page {
        guard let notebook = page.notebook else { throw DocumentStoreError.notFound }
        let copy = try addPage(to: notebook, after: page, template: page.template)
        copy.drawingData = page.drawingData
        copy.thumbnailData = page.thumbnailData
        return copy
    }

    public func updateDrawing(for page: Page, drawingData: Data) throws {
        page.drawingData = drawingData
        page.modifiedAt = .now
        page.notebook.map(touch)
    }

    public func save() throws { /* no-op for in-memory */ }

    // MARK: Helpers

    private func touch(_ folder: Folder) { folder.modifiedAt = .now }
    private func touch(_ notebook: Notebook) { notebook.modifiedAt = .now }

    private func seedSample() {
        let folder = try? createFolder(name: "School", parent: nil)
        _ = try? createNotebook(title: "Lecture Notes", in: folder, template: .lined)
        _ = try? createNotebook(title: "Sketchbook", in: nil, template: .dotted)
    }
}
