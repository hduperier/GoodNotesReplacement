import XCTest
import SwiftData
@testable import GoodNotesReplacement

/// A `ThumbnailService` test double that returns fixed bytes without touching
/// PencilKit. Records call count so tests can assert thumbnail refresh fired.
@MainActor
final class StubThumbnailService: ThumbnailService {
    /// The bytes every `renderThumbnail` call returns.
    static let fixedThumbnail = Data("STUB-THUMB".utf8)

    private(set) var renderCount = 0
    /// When set, `renderThumbnail` throws to exercise tolerance of failures.
    var errorToThrow: Error?

    func renderThumbnail(
        drawingData: Data?,
        template: PaperTemplate,
        pointSize: CGSize,
        scale: CGFloat
    ) throws -> Data {
        renderCount += 1
        if let errorToThrow { throw errorToThrow }
        return Self.fixedThumbnail
    }
}

/// Drives the shared `DocumentStoreContractTests` against the real
/// `SwiftDataDocumentStore` backed by an in-memory `ModelContainer`.
@MainActor
final class SwiftDataDocumentStoreContractTests: DocumentStoreContractTests {

    private var container: ModelContainer!
    private var thumbnails: StubThumbnailService!

    // Use the *async* setUp/tearDown overrides. The synchronous ones are
    // nonisolated (inherited from XCTestCase) and so can't mutate these
    // main-actor-isolated fixtures; an async override, by contrast, picks up
    // the class's @MainActor isolation, so the body runs on the main actor.
    override func setUp() async throws {
        container = try ModelContainer(
            for: AppSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        thumbnails = StubThumbnailService()
    }

    override func tearDown() async throws {
        container = nil
        thumbnails = nil
    }

    override func makeStore() throws -> DocumentStore? {
        SwiftDataDocumentStore(context: container.mainContext, thumbnails: thumbnails)
    }

    // MARK: - Read-back hooks via real fetches

    override func allFolderIDs(_ store: DocumentStore) throws -> [UUID] {
        try container.mainContext.fetch(FetchDescriptor<Folder>()).map(\.id)
    }

    override func allNotebookIDs(_ store: DocumentStore) throws -> [UUID] {
        try container.mainContext.fetch(FetchDescriptor<Notebook>()).map(\.id)
    }

    override func allPageIDs(_ store: DocumentStore) throws -> [UUID] {
        try container.mainContext.fetch(FetchDescriptor<Page>()).map(\.id)
    }

    override func fetchPage(_ store: DocumentStore, id: UUID) throws -> Page? {
        let descriptor = FetchDescriptor<Page>(predicate: #Predicate { $0.id == id })
        return try container.mainContext.fetch(descriptor).first
    }
}

/// SwiftData-specific tests that don't apply to the in-memory double: schema
/// builds, container persistence semantics, and thumbnail-refresh wiring.
@MainActor
final class SwiftDataDocumentStorePersistenceTests: XCTestCase {

    private func makeStore() throws -> (SwiftDataDocumentStore, ModelContainer, StubThumbnailService) {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let stub = StubThumbnailService()
        let store = SwiftDataDocumentStore(context: container.mainContext, thumbnails: stub)
        return (store, container, stub)
    }

    func test_staticSchema_matchesAppSchema() {
        XCTAssertEqual(
            Set(SwiftDataDocumentStore.schema.entities.map(\.name)),
            Set(AppSchema.schema.entities.map(\.name))
        )
    }

    func test_createNotebook_persistsExactlyOnePageToContext() throws {
        let (store, container, _) = try makeStore()
        _ = try store.createNotebook(title: "N", in: nil, template: .lined)

        let pages = try container.mainContext.fetch(FetchDescriptor<Page>())
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first?.index, 0)
    }

    /// Awaits the store's fire-and-forget thumbnail `Task` by suspending this
    /// (main-actor) test, which lets the cooperative executor run it. Returns
    /// once `stub.renderCount` reaches `count`, or fails on timeout.
    private func awaitRenderCount(
        _ stub: StubThumbnailService, atLeast count: Int, timeout: TimeInterval = 2.0
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while stub.renderCount < count && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }

    func test_updateDrawing_eventuallyRefreshesThumbnail() async throws {
        // Hold the container for the whole test: the thumbnail refresh runs on a
        // later Task that saves through the store's context, which is only valid
        // while its ModelContainer is alive. (In the app the container lives for
        // the process lifetime; dropping it here would crash that deferred save.)
        let (store, container, stub) = try makeStore()
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let page = notebook.orderedPages[0]

        try store.updateDrawing(for: page, drawingData: Data([1, 2, 3]))

        // The store dispatches thumbnail rendering on a low-priority main-actor
        // Task; suspend until it lands (or time out).
        await awaitRenderCount(stub, atLeast: 1)

        XCTAssertGreaterThanOrEqual(stub.renderCount, 1,
                                    "updateDrawing should trigger a thumbnail refresh.")
        XCTAssertEqual(page.thumbnailData, StubThumbnailService.fixedThumbnail)
        withExtendedLifetime(container) {}
    }

    func test_updateDrawing_toleratesThumbnailFailure() async throws {
        let (store, container, stub) = try makeStore()
        stub.errorToThrow = DocumentStoreError.persistenceFailure("boom")
        let notebook = try store.createNotebook(title: "N", in: nil, template: .lined)
        let page = notebook.orderedPages[0]
        let ink = Data([4, 5, 6])

        // Must not throw despite the thumbnail service erroring.
        XCTAssertNoThrow(try store.updateDrawing(for: page, drawingData: ink))

        // Let the dispatched task run (it renders, then throws and is swallowed);
        // ink stays intact and the thumbnail cache is left untouched (nil).
        await awaitRenderCount(stub, atLeast: 1)
        XCTAssertEqual(page.drawingData, ink)
        XCTAssertNil(page.thumbnailData)
        withExtendedLifetime(container) {}
    }

    func test_dataSurvivesNewContextOnSameContainer() throws {
        let (store, container, _) = try makeStore()
        let notebook = try store.createNotebook(title: "Persisted", in: nil, template: .grid)
        let page = notebook.orderedPages[0]
        let ink = Data([7, 7, 7])
        try store.updateDrawing(for: page, drawingData: ink)
        try store.save()
        let notebookID = notebook.id

        // A fresh context on the same in-memory container should see the data.
        let freshContext = ModelContext(container)
        let fetched = try freshContext.fetch(
            FetchDescriptor<Notebook>(predicate: #Predicate { $0.id == notebookID })
        )
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.pages.first?.drawingData, ink)
    }
}
