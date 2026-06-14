import XCTest
import SwiftData
@testable import GoodNotesReplacement

/// Flashcard set/card behavior against the real `SwiftDataDocumentStore` backed
/// by an in-memory `ModelContainer`. Mirrors `InMemoryFlashcardStoreTests` so the
/// same contract holds for both `DocumentStore` implementations, and adds
/// fetch-based persistence checks specific to SwiftData.
@MainActor
final class SwiftDataFlashcardStoreTests: XCTestCase {

    private var container: ModelContainer!
    private var store: SwiftDataDocumentStore!

    override func setUp() async throws {
        container = try ModelContainer(
            for: AppSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = SwiftDataDocumentStore(
            context: container.mainContext,
            thumbnails: StubThumbnailService()
        )
    }

    override func tearDown() async throws {
        store = nil
        container = nil
    }

    private func allSets() throws -> [FlashcardSet] {
        try container.mainContext.fetch(FetchDescriptor<FlashcardSet>())
    }

    private func allCards() throws -> [Flashcard] {
        try container.mainContext.fetch(FetchDescriptor<Flashcard>())
    }

    // MARK: - Sets

    func test_createFlashcardSet_persistsSetWithOneCard() throws {
        _ = try store.createFlashcardSet(title: "S", in: nil)
        XCTAssertEqual(try allSets().count, 1)
        let cards = try allCards()
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.index, 0)
    }

    func test_deleteFlashcardSet_cascadesToCards() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        _ = try store.addCard(to: set, after: nil)
        XCTAssertEqual(try allCards().count, 2)

        try store.deleteFlashcardSet(set)
        XCTAssertTrue(try allSets().isEmpty)
        XCTAssertTrue(try allCards().isEmpty, "Deleting a set should cascade to its cards.")
    }

    func test_deleteFolder_cascadesToFlashcardSetsAndCards() throws {
        let folder = try store.createFolder(name: "F", parent: nil)
        _ = try store.createFlashcardSet(title: "S", in: folder)
        XCTAssertEqual(try allSets().count, 1)

        try store.deleteFolder(folder)
        XCTAssertTrue(try allSets().isEmpty, "Deleting a folder should cascade to its sets.")
        XCTAssertTrue(try allCards().isEmpty)
    }

    func test_duplicateFlashcardSet_deepCopiesCardsInContext() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        try store.updateCard(set.orderedCards[0], frontText: "Hello", backText: "Hola",
                             frontDrawing: Data([1, 2]), backDrawing: nil)

        let copy = try store.duplicateFlashcardSet(set)
        XCTAssertEqual(copy.title, "S copy")
        XCTAssertEqual(try allSets().count, 2)
        XCTAssertEqual(try allCards().count, 2) // one card per set
        XCTAssertEqual(copy.orderedCards[0].frontText, "Hello")
        XCTAssertEqual(copy.orderedCards[0].frontDrawingData, Data([1, 2]))
    }

    func test_moveFlashcardSet_updatesFolderAndSurvivesFetch() throws {
        let folder = try store.createFolder(name: "F", parent: nil)
        let set = try store.createFlashcardSet(title: "S", in: nil)
        try store.moveFlashcardSet(set, into: folder)

        let setID = set.id
        let fetched = try container.mainContext.fetch(
            FetchDescriptor<FlashcardSet>(predicate: #Predicate { $0.id == setID })
        )
        XCTAssertEqual(fetched.first?.folder?.id, folder.id)
    }

    // MARK: - Cards

    func test_addCard_keepsContiguousIndices() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        _ = try store.addCard(to: set, after: nil)
        _ = try store.addCard(to: set, after: nil)
        XCTAssertEqual(set.orderedCards.map(\.index), [0, 1, 2])
    }

    func test_deleteCard_closesIndexGap() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        let c1 = try store.addCard(to: set, after: nil)
        _ = try store.addCard(to: set, after: nil)
        try store.deleteCard(c1)
        XCTAssertEqual(set.orderedCards.map(\.index), [0, 1])
    }

    func test_moveCard_reindexes() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        _ = try store.addCard(to: set, after: nil)
        _ = try store.addCard(to: set, after: nil)
        let first = set.orderedCards[0]
        try store.moveCard(first, to: 2)
        XCTAssertEqual(set.orderedCards.last?.id, first.id)
        XCTAssertEqual(set.orderedCards.map(\.index), [0, 1, 2])
    }

    func test_updateCard_persistsThroughFreshContext() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        let card = set.orderedCards[0]
        try store.updateCard(card, frontText: "Q", backText: "A",
                             frontDrawing: Data([5]), backDrawing: Data([6]))
        try store.save()
        let cardID = card.id

        let freshContext = ModelContext(container)
        let fetched = try freshContext.fetch(
            FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == cardID })
        )
        XCTAssertEqual(fetched.first?.frontText, "Q")
        XCTAssertEqual(fetched.first?.backText, "A")
        XCTAssertEqual(fetched.first?.frontDrawingData, Data([5]))
    }
}
