import XCTest
import SwiftData
@testable import GoodNotesReplacement

/// Flashcard set/card behavior against `InMemoryDocumentStore`. Mirrors the
/// notebook/page invariant tests; the same contract is exercised against the
/// SwiftData store in `SwiftDataFlashcardStoreTests`.
@MainActor
final class InMemoryFlashcardStoreTests: XCTestCase {

    private var store: InMemoryDocumentStore!

    override func setUp() async throws {
        store = InMemoryDocumentStore(seed: false)
    }

    override func tearDown() async throws {
        store = nil
    }

    // MARK: - Sets

    func test_createFlashcardSet_seedsOneBlankCard_atRoot() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        XCTAssertEqual(store.rootFlashcardSets.count, 1)
        XCTAssertEqual(set.cardCount, 1)
        XCTAssertEqual(set.orderedCards.first?.index, 0)
        XCTAssertTrue(set.orderedCards.first?.isBlank ?? false)
    }

    func test_createFlashcardSet_inFolder_attachesToFolder() throws {
        let folder = try store.createFolder(name: "F", parent: nil)
        let set = try store.createFlashcardSet(title: "S", in: folder)
        XCTAssertTrue(store.rootFlashcardSets.isEmpty)
        XCTAssertEqual(folder.flashcardSets.count, 1)
        XCTAssertIdentical(set.folder, folder)
    }

    func test_renameFlashcardSet() throws {
        let set = try store.createFlashcardSet(title: "Old", in: nil)
        try store.renameFlashcardSet(set, to: "New")
        XCTAssertEqual(set.title, "New")
    }

    func test_deleteFlashcardSet_removesFromRoot() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        try store.deleteFlashcardSet(set)
        XCTAssertTrue(store.rootFlashcardSets.isEmpty)
    }

    func test_moveFlashcardSet_betweenRootAndFolder() throws {
        let folder = try store.createFolder(name: "F", parent: nil)
        let set = try store.createFlashcardSet(title: "S", in: nil)

        try store.moveFlashcardSet(set, into: folder)
        XCTAssertTrue(store.rootFlashcardSets.isEmpty)
        XCTAssertEqual(folder.flashcardSets.count, 1)

        try store.moveFlashcardSet(set, into: nil)
        XCTAssertEqual(store.rootFlashcardSets.count, 1)
        XCTAssertTrue(folder.flashcardSets.isEmpty)
    }

    func test_duplicateFlashcardSet_deepCopiesCards() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        let first = set.orderedCards[0]
        try store.updateCard(first, frontText: "Hello", backText: "Hola",
                             frontDrawing: Data([1, 2]), backDrawing: nil)
        _ = try store.addCard(to: set, after: nil)

        let copy = try store.duplicateFlashcardSet(set)
        XCTAssertEqual(copy.title, "S copy")
        XCTAssertEqual(copy.cardCount, set.cardCount)
        // Distinct card instances, identical content.
        XCTAssertFalse(copy.orderedCards.contains { original in
            set.cards.contains { $0 === original }
        })
        XCTAssertEqual(copy.orderedCards[0].frontText, "Hello")
        XCTAssertEqual(copy.orderedCards[0].backText, "Hola")
        XCTAssertEqual(copy.orderedCards[0].frontDrawingData, Data([1, 2]))
    }

    // MARK: - Cards

    func test_addCard_appendsWithContiguousIndices() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        _ = try store.addCard(to: set, after: nil)
        _ = try store.addCard(to: set, after: nil)
        XCTAssertEqual(set.orderedCards.map(\.index), [0, 1, 2])
    }

    func test_addCard_afterCard_insertsAndShifts() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        let first = set.orderedCards[0]
        let second = try store.addCard(to: set, after: nil) // index 1
        let inserted = try store.addCard(to: set, after: first) // becomes index 1

        XCTAssertEqual(inserted.index, 1)
        XCTAssertEqual(second.index, 2)
        XCTAssertEqual(set.orderedCards.map(\.index), [0, 1, 2])
    }

    func test_updateCard_setsTextAndInk() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        let card = set.orderedCards[0]
        try store.updateCard(card, frontText: "Q", backText: "A",
                             frontDrawing: Data([9]), backDrawing: Data([8]))
        XCTAssertEqual(card.frontText, "Q")
        XCTAssertEqual(card.backText, "A")
        XCTAssertEqual(card.frontDrawingData, Data([9]))
        XCTAssertEqual(card.backDrawingData, Data([8]))
    }

    func test_deleteCard_closesIndexGap() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        let c1 = try store.addCard(to: set, after: nil)
        _ = try store.addCard(to: set, after: nil)
        try store.deleteCard(c1)
        XCTAssertEqual(set.orderedCards.map(\.index), [0, 1])
        XCTAssertEqual(set.cardCount, 2)
    }

    func test_moveCard_reindexesContiguously() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        let c1 = try store.addCard(to: set, after: nil)
        _ = try store.addCard(to: set, after: nil)
        // Move the first card to the end.
        let first = set.orderedCards[0]
        try store.moveCard(first, to: 2)
        XCTAssertEqual(set.orderedCards.last?.id, first.id)
        XCTAssertEqual(set.orderedCards.map(\.index), [0, 1, 2])
        XCTAssertEqual(set.orderedCards[0].id, c1.id)
    }

    func test_moveCard_invalidIndex_throws() throws {
        let set = try store.createFlashcardSet(title: "S", in: nil)
        let card = set.orderedCards[0]
        XCTAssertThrowsError(try store.moveCard(card, to: 5))
    }

    // MARK: - Seed

    func test_seed_includesDemoFlashcardSet() {
        let seeded = InMemoryDocumentStore(seed: true)
        XCTAssertEqual(seeded.rootFlashcardSets.count, 1)
        let set = seeded.rootFlashcardSets.first
        XCTAssertEqual(set?.title, "Spanish Basics")
        XCTAssertEqual(set?.cardCount, 3)
        XCTAssertEqual(set?.orderedCards.first?.frontText, "Hello")
        XCTAssertEqual(set?.orderedCards.first?.backText, "Hola")
    }
}
