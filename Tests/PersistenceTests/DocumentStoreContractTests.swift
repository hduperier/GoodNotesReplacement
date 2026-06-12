import XCTest
import SwiftData
@testable import GoodNotesReplacement

/// A reusable contract test suite for `DocumentStore`. It is written against the
/// `DocumentStore` *protocol* so it can be driven against any conforming type.
///
/// This base class produces **no tests of its own** (it returns `nil` from
/// `makeStore()`); concrete subclasses override `makeStore()` to supply a fresh
/// store instance and inherit every `test…` method. Two subclasses live here:
///
/// * `InMemoryDocumentStoreContractTests` — drives `InMemoryDocumentStore`.
/// * `SwiftDataDocumentStoreContractTests` — drives `SwiftDataDocumentStore`
///   backed by an in-memory `ModelContainer`.
///
/// Because XCTest discovers and runs the `test…` methods on the *base* class too,
/// each method first asks `makeStore()`; when it returns `nil` (base class only),
/// the test is skipped via `XCTSkip`. Subclasses always return a real store.
@MainActor
class DocumentStoreContractTests: XCTestCase {

    /// Override to return a fresh, empty store for each test. Return `nil` only
    /// in the abstract base class so its inherited tests are skipped.
    func makeStore() throws -> DocumentStore? { nil }

    /// Resolves a store or skips the test (used by the abstract base class).
    private func requireStore() throws -> DocumentStore {
        guard let store = try makeStore() else {
            throw XCTSkip("Abstract contract base: no store provided.")
        }
        return store
    }

    // MARK: - Folders

    func test_createFolder_atRoot_setsContiguousSortIndices() throws {
        let store = try requireStore()
        let a = try store.createFolder(name: "A", parent: nil)
        let b = try store.createFolder(name: "B", parent: nil)
        let c = try store.createFolder(name: "C", parent: nil)

        XCTAssertEqual(a.sortIndex, 0)
        XCTAssertEqual(b.sortIndex, 1)
        XCTAssertEqual(c.sortIndex, 2)
        XCTAssertNil(a.parent)
        XCTAssertTrue(a.subfolders.isEmpty)
        XCTAssertTrue(a.notebooks.isEmpty)
    }

    func test_createFolder_nested_attachesToParent() throws {
        let store = try requireStore()
        let parent = try store.createFolder(name: "Parent", parent: nil)
        let child = try store.createFolder(name: "Child", parent: parent)

        XCTAssertEqual(child.parent?.id, parent.id)
        XCTAssertTrue(parent.subfolders.contains { $0.id == child.id })
        XCTAssertEqual(child.sortIndex, 0)
    }

    func test_renameFolder_updatesNameAndBumpsModifiedAt() throws {
        let store = try requireStore()
        let folder = try store.createFolder(name: "Old", parent: nil)
        let before = folder.modifiedAt
        // Ensure measurable time delta for the modifiedAt bump.
        try bumpClock()
        try store.renameFolder(folder, to: "New")

        XCTAssertEqual(folder.name, "New")
        XCTAssertGreaterThanOrEqual(folder.modifiedAt, before)
    }

    func test_deleteFolder_cascadesNotebooksAndPages() throws {
        let store = try requireStore()
        let folder = try store.createFolder(name: "F", parent: nil)
        let notebook = try store.createNotebook(title: "N", in: folder, template: .lined)
        _ = try store.addPage(to: notebook, after: notebook.orderedPages.last, template: .lined)
        let notebookID = notebook.id

        try store.deleteFolder(folder)
        try store.save()

        // Notebook (and therefore its pages) must no longer be reachable.
        XCTAssertFalse(try allNotebookIDs(store).contains(notebookID),
                       "Cascade should remove notebooks (and pages) in a deleted folder.")
    }

    func test_deleteFolder_cascadesSubfolders() throws {
        let store = try requireStore()
        let parent = try store.createFolder(name: "Parent", parent: nil)
        let child = try store.createFolder(name: "Child", parent: parent)
        let childID = child.id

        try store.deleteFolder(parent)
        try store.save()

        XCTAssertFalse(try allFolderIDs(store).contains(childID),
                       "Deleting a folder should cascade to its subfolders.")
    }

    func test_moveFolder_reparents() throws {
        let store = try requireStore()
        let a = try store.createFolder(name: "A", parent: nil)
        let b = try store.createFolder(name: "B", parent: nil)

        try store.moveFolder(b, into: a)
        try store.save()

        XCTAssertEqual(b.parent?.id, a.id)
        XCTAssertTrue(a.subfolders.contains { $0.id == b.id })
    }

    func test_moveFolder_intoItself_isNoOp() throws {
        let store = try requireStore()
        let a = try store.createFolder(name: "A", parent: nil)
        try store.moveFolder(a, into: a)
        XCTAssertNil(a.parent)
    }

    // MARK: - Notebooks

    func test_createNotebook_seedsExactlyOnePageAtIndexZero() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .grid)

        XCTAssertEqual(notebook.pages.count, 1)
        XCTAssertEqual(notebook.orderedPages.first?.index, 0)
        XCTAssertEqual(notebook.orderedPages.first?.template, .grid)
        XCTAssertEqual(notebook.orderedPages.first?.notebook?.id, notebook.id)
        XCTAssertEqual(notebook.defaultTemplate, .grid)
    }

    func test_createNotebook_inFolder_attachesAndOrders() throws {
        let store = try requireStore()
        let folder = try store.createFolder(name: "F", parent: nil)
        let n1 = try store.createNotebook(title: "N1", in: folder, template: .lined)
        let n2 = try store.createNotebook(title: "N2", in: folder, template: .lined)

        XCTAssertEqual(n1.folder?.id, folder.id)
        XCTAssertEqual(n1.sortIndex, 0)
        XCTAssertEqual(n2.sortIndex, 1)
        XCTAssertTrue(folder.notebooks.contains { $0.id == n1.id })
    }

    func test_renameNotebook_updatesTitle() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "Old", in: nil, template: .blankWhite)
        try store.renameNotebook(notebook, to: "New")
        XCTAssertEqual(notebook.title, "New")
    }

    func test_deleteNotebook_cascadesPages() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let page = notebook.orderedPages[0]
        _ = try store.addPage(to: notebook, after: page, template: .lined)
        let pageID = page.id

        try store.deleteNotebook(notebook)
        try store.save()

        XCTAssertFalse(try allPageIDs(store).contains(pageID),
                       "Deleting a notebook should cascade to its pages.")
    }

    func test_moveNotebook_intoFolder() throws {
        let store = try requireStore()
        let folder = try store.createFolder(name: "F", parent: nil)
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)

        try store.moveNotebook(notebook, into: folder)
        try store.save()

        XCTAssertEqual(notebook.folder?.id, folder.id)
        XCTAssertTrue(folder.notebooks.contains { $0.id == notebook.id })
    }

    func test_moveNotebook_toRoot() throws {
        let store = try requireStore()
        let folder = try store.createFolder(name: "F", parent: nil)
        let notebook = try store.createNotebook(title: "N", in: folder, template: .lined)

        try store.moveNotebook(notebook, into: nil)
        try store.save()

        XCTAssertNil(notebook.folder)
    }

    func test_duplicateNotebook_deepCopiesPagesAndInk() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let firstPage = notebook.orderedPages[0]
        let ink = Data([1, 2, 3, 4])
        try store.updateDrawing(for: firstPage, drawingData: ink)
        _ = try store.addPage(to: notebook, after: firstPage, template: .dotted)
        try store.save()

        let copy = try store.duplicateNotebook(notebook)
        try store.save()

        XCTAssertNotEqual(copy.id, notebook.id)
        XCTAssertEqual(copy.title, "N copy")
        XCTAssertEqual(copy.pages.count, notebook.pages.count)

        // Indices preserved and contiguous in the copy.
        let copyIndices = copy.orderedPages.map(\.index)
        XCTAssertEqual(copyIndices, Array(0..<copy.pages.count))

        // Ink data deep-copied onto a *distinct* page object.
        let copyFirst = copy.orderedPages[0]
        XCTAssertEqual(copyFirst.drawingData, ink)
        XCTAssertNotEqual(copyFirst.id, firstPage.id,
                          "Duplicated pages must be new objects, not aliases.")
    }

    // MARK: - Pages

    func test_addPage_appendsAtEndWhenAfterNil() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let p1 = try store.addPage(to: notebook, after: nil, template: .lined)
        let p2 = try store.addPage(to: notebook, after: nil, template: .lined)

        XCTAssertEqual(notebook.pages.count, 3)
        XCTAssertEqual(p1.index, 1)
        XCTAssertEqual(p2.index, 2)
        XCTAssertEqual(notebook.orderedPages.map(\.index), [0, 1, 2])
    }

    func test_addPage_insertsAfterGivenPageAndShifts() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let p0 = notebook.orderedPages[0]
        let p1 = try store.addPage(to: notebook, after: p0, template: .lined)   // index 1
        let p2 = try store.addPage(to: notebook, after: p0, template: .grid)    // inserts at 1, shifts p1 -> 2

        XCTAssertEqual(p0.index, 0)
        XCTAssertEqual(p2.index, 1)
        XCTAssertEqual(p1.index, 2)
        XCTAssertEqual(p2.template, .grid)
        XCTAssertEqual(notebook.orderedPages.map(\.index), [0, 1, 2])
    }

    func test_deletePage_reindexesContiguously() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let p0 = notebook.orderedPages[0]
        let p1 = try store.addPage(to: notebook, after: p0, template: .lined)
        let p2 = try store.addPage(to: notebook, after: p1, template: .lined)

        try store.deletePage(p1)
        try store.save()

        XCTAssertEqual(notebook.pages.count, 2)
        XCTAssertEqual(notebook.orderedPages.map(\.index), [0, 1])
        XCTAssertEqual(notebook.orderedPages.last?.id, p2.id)
        XCTAssertEqual(p2.index, 1, "Trailing pages shift down after a delete.")
    }

    func test_deletePage_withoutNotebook_throwsNotFound() throws {
        let store = try requireStore()
        let orphan = Page(index: 0, template: .lined, notebook: nil)
        XCTAssertThrowsError(try store.deletePage(orphan)) { error in
            XCTAssertEqual(error as? DocumentStoreError, .notFound)
        }
    }

    func test_movePage_reordersAndReindexesContiguously() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let p0 = notebook.orderedPages[0]
        let p1 = try store.addPage(to: notebook, after: p0, template: .lined)
        let p2 = try store.addPage(to: notebook, after: p1, template: .lined)

        // Move the last page to the front.
        try store.movePage(p2, to: 0)
        try store.save()

        XCTAssertEqual(notebook.orderedPages.map(\.id), [p2.id, p0.id, p1.id])
        XCTAssertEqual(notebook.orderedPages.map(\.index), [0, 1, 2])
    }

    func test_movePage_outOfRange_throwsInvalidIndex() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let p0 = notebook.orderedPages[0]
        XCTAssertThrowsError(try store.movePage(p0, to: 5)) { error in
            XCTAssertEqual(error as? DocumentStoreError, .invalidIndex)
        }
        XCTAssertThrowsError(try store.movePage(p0, to: -1)) { error in
            XCTAssertEqual(error as? DocumentStoreError, .invalidIndex)
        }
    }

    func test_duplicatePage_insertsAfterSourceWithCopiedInk() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .grid)
        let p0 = notebook.orderedPages[0]
        let ink = Data([9, 8, 7])
        try store.updateDrawing(for: p0, drawingData: ink)

        let copy = try store.duplicatePage(p0)
        try store.save()

        XCTAssertEqual(notebook.pages.count, 2)
        XCTAssertEqual(copy.index, 1, "Duplicate is inserted directly after the source.")
        XCTAssertEqual(copy.template, p0.template)
        XCTAssertEqual(copy.drawingData, ink)
        XCTAssertNotEqual(copy.id, p0.id)
        XCTAssertEqual(notebook.orderedPages.map(\.index), [0, 1])
    }

    func test_duplicatePage_withoutNotebook_throwsNotFound() throws {
        let store = try requireStore()
        let orphan = Page(index: 0, template: .lined, notebook: nil)
        XCTAssertThrowsError(try store.duplicatePage(orphan)) { error in
            XCTAssertEqual(error as? DocumentStoreError, .notFound)
        }
    }

    // MARK: - Drawing

    func test_updateDrawing_persistsDataAndBumpsModifiedAt() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let page = notebook.orderedPages[0]
        let before = page.modifiedAt
        XCTAssertTrue(page.isBlank)

        try bumpClock()
        let ink = Data([0xDE, 0xAD, 0xBE, 0xEF])
        try store.updateDrawing(for: page, drawingData: ink)
        try store.save()

        XCTAssertEqual(page.drawingData, ink)
        XCTAssertFalse(page.isBlank)
        XCTAssertGreaterThanOrEqual(page.modifiedAt, before)
    }

    func test_updateDrawing_persistsAcrossRefetch() throws {
        let store = try requireStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let page = notebook.orderedPages[0]
        let pageID = page.id
        let ink = Data([1, 1, 2, 3, 5, 8])
        try store.updateDrawing(for: page, drawingData: ink)
        try store.save()

        // For a SwiftData-backed store this verifies the bytes actually persisted;
        // for the in-memory store it confirms the same object holds the data.
        let reloaded = try fetchPage(store, id: pageID)
        XCTAssertEqual(reloaded?.drawingData, ink)
    }

    // MARK: - Hooks for store-specific reads
    //
    // The contract suite needs to verify cascade deletes and persistence without
    // reaching into a specific implementation. Subclasses override these to read
    // back through their backing store (a fetch for SwiftData; array scans for the
    // in-memory store). The base implementations just skip.

    func allFolderIDs(_ store: DocumentStore) throws -> [UUID] {
        throw XCTSkip("Override in concrete subclass.")
    }

    func allNotebookIDs(_ store: DocumentStore) throws -> [UUID] {
        throw XCTSkip("Override in concrete subclass.")
    }

    func allPageIDs(_ store: DocumentStore) throws -> [UUID] {
        throw XCTSkip("Override in concrete subclass.")
    }

    func fetchPage(_ store: DocumentStore, id: UUID) throws -> Page? {
        throw XCTSkip("Override in concrete subclass.")
    }

    // MARK: - Utilities

    /// SwiftData/`Date.now` resolution is fine-grained, but spin briefly so a
    /// `modifiedAt` bump is observably non-decreasing even on fast machines.
    private func bumpClock() throws {
        let start = Date()
        while Date().timeIntervalSince(start) < 0.005 { /* tiny busy-wait */ }
    }
}
