import XCTest
import SwiftData
@testable import GoodNotesReplacement

/// Runs the shared `DocumentStoreContractTests` suite against
/// `InMemoryDocumentStore`. This guarantees the preview/test double obeys the
/// same contract as `SwiftDataDocumentStore`, so anything written against the
/// `DocumentStore` protocol behaves identically on both.
@MainActor
final class InMemoryDocumentStoreContractTests: DocumentStoreContractTests {

    private var store: InMemoryDocumentStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = InMemoryDocumentStore(seed: false)
    }

    override func tearDownWithError() throws {
        store = nil
        try super.tearDownWithError()
    }

    override func makeStore() throws -> DocumentStore? { store }

    // MARK: - Read-back hooks via in-memory traversal

    private func allFolders(_ root: [Folder]) -> [Folder] {
        root + root.flatMap { allFolders($0.subfolders) }
    }

    override func allFolderIDs(_ store: DocumentStore) throws -> [UUID] {
        allFolders(self.store.rootFolders).map(\.id)
    }

    override func allNotebookIDs(_ store: DocumentStore) throws -> [UUID] {
        let nested = allFolders(self.store.rootFolders).flatMap(\.notebooks)
        return (self.store.rootNotebooks + nested).map(\.id)
    }

    override func allPageIDs(_ store: DocumentStore) throws -> [UUID] {
        let nested = allFolders(self.store.rootFolders).flatMap(\.notebooks)
        return (self.store.rootNotebooks + nested).flatMap(\.pages).map(\.id)
    }

    override func fetchPage(_ store: DocumentStore, id: UUID) throws -> Page? {
        let nested = allFolders(self.store.rootFolders).flatMap(\.notebooks)
        return (self.store.rootNotebooks + nested)
            .flatMap(\.pages)
            .first { $0.id == id }
    }
}

/// Invariants specific to `InMemoryDocumentStore` (root-array bookkeeping, seed
/// behavior, schema identity) that don't fit the protocol contract suite.
@MainActor
final class InMemoryDocumentStoreInvariantTests: XCTestCase {

    func test_emptyStore_hasNoRoots() {
        let store = InMemoryDocumentStore(seed: false)
        XCTAssertTrue(store.rootFolders.isEmpty)
        XCTAssertTrue(store.rootNotebooks.isEmpty)
    }

    func test_seed_populatesSampleLibrary() {
        let store = InMemoryDocumentStore(seed: true)
        XCTAssertEqual(store.rootFolders.count, 1)
        XCTAssertEqual(store.rootFolders.first?.name, "School")
        // "Lecture Notes" lives in the folder; "Sketchbook" at root.
        XCTAssertEqual(store.rootFolders.first?.notebooks.count, 1)
        XCTAssertEqual(store.rootNotebooks.count, 1)
        XCTAssertEqual(store.rootNotebooks.first?.title, "Sketchbook")
        // Every seeded notebook has its single seed page.
        XCTAssertEqual(store.rootNotebooks.first?.pages.count, 1)
    }

    func test_deleteFolder_removesFromRootArray() throws {
        let store = InMemoryDocumentStore(seed: false)
        let folder = try store.createFolder(name: "F", parent: nil)
        XCTAssertEqual(store.rootFolders.count, 1)
        try store.deleteFolder(folder)
        XCTAssertTrue(store.rootFolders.isEmpty)
    }

    func test_deleteNotebook_removesFromRootArray() throws {
        let store = InMemoryDocumentStore(seed: false)
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        XCTAssertEqual(store.rootNotebooks.count, 1)
        try store.deleteNotebook(notebook)
        XCTAssertTrue(store.rootNotebooks.isEmpty)
    }

    func test_moveNotebook_movesBetweenRootAndFolder() throws {
        let store = InMemoryDocumentStore(seed: false)
        let folder = try store.createFolder(name: "F", parent: nil)
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        XCTAssertEqual(store.rootNotebooks.count, 1)

        try store.moveNotebook(notebook, into: folder)
        XCTAssertTrue(store.rootNotebooks.isEmpty)
        XCTAssertEqual(folder.notebooks.count, 1)

        try store.moveNotebook(notebook, into: nil)
        XCTAssertEqual(store.rootNotebooks.count, 1)
        XCTAssertTrue(folder.notebooks.isEmpty)
    }

    func test_staticSchema_matchesAppSchema() {
        XCTAssertEqual(
            Set(InMemoryDocumentStore.schema.entities.map(\.name)),
            Set(AppSchema.schema.entities.map(\.name))
        )
    }

    func test_save_isNoOpAndDoesNotThrow() {
        let store = InMemoryDocumentStore(seed: false)
        XCTAssertNoThrow(try store.save())
    }
}
