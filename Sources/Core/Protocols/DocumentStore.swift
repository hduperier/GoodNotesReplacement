import Foundation
import SwiftData

/// High-level library + document operations. The UI layer depends only on this
/// protocol; the Persistence layer provides the SwiftData-backed implementation
/// and `InMemoryDocumentStore` provides a preview/test double.
///
/// Trivial reads (listing folders, observing a notebook's pages) are expected to
/// use SwiftData's `@Query` directly in views. This protocol covers the
/// non-trivial mutations that need cascade/ordering/thumbnail bookkeeping.
@MainActor
public protocol DocumentStore: AnyObject {

    // MARK: Schema
    /// The complete model schema, used to build the `ModelContainer`.
    static var schema: Schema { get }

    // MARK: Folders
    @discardableResult
    func createFolder(name: String, parent: Folder?) throws -> Folder
    func renameFolder(_ folder: Folder, to name: String) throws
    func deleteFolder(_ folder: Folder) throws
    func moveFolder(_ folder: Folder, into parent: Folder?) throws

    // MARK: Notebooks
    /// Creates a notebook seeded with one blank page using `template`.
    @discardableResult
    func createNotebook(title: String, in folder: Folder?, template: PaperTemplate) throws -> Notebook
    func renameNotebook(_ notebook: Notebook, to title: String) throws
    func deleteNotebook(_ notebook: Notebook) throws
    func moveNotebook(_ notebook: Notebook, into folder: Folder?) throws
    @discardableResult
    func duplicateNotebook(_ notebook: Notebook) throws -> Notebook

    // MARK: Pages
    /// Inserts a new page after `page` (or at the end when nil).
    @discardableResult
    func addPage(to notebook: Notebook, after page: Page?, template: PaperTemplate) throws -> Page
    func deletePage(_ page: Page) throws
    func movePage(_ page: Page, to index: Int) throws
    @discardableResult
    func duplicatePage(_ page: Page) throws -> Page

    /// Persists new ink for a page and refreshes its cached thumbnail.
    /// `drawingData` is `PKDrawing.dataRepresentation()`.
    func updateDrawing(for page: Page, drawingData: Data) throws

    func save() throws
}

public enum DocumentStoreError: Error, Equatable, Sendable {
    case notFound
    case invalidIndex
    case persistenceFailure(String)
}
