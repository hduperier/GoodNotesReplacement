import Foundation
import SwiftData

/// A flashcard set (Quizlet-style "set"): an ordered collection of cards plus
/// cover metadata. A first-class library item that lives on the shelf next to
/// notebooks and inside the same folders.
@Model
public final class FlashcardSet {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date
    /// Manual sort position within its folder (or the root library).
    public var sortIndex: Int

    /// Cover color shown on the library shelf, #RRGGBB.
    public var coverColorHex: String

    @Relationship(deleteRule: .nullify)
    public var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Flashcard.set)
    public var cards: [Flashcard]

    public init(
        id: UUID = UUID(),
        title: String,
        folder: Folder? = nil,
        coverColorHex: String = "#C9962A",
        sortIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.folder = folder
        self.coverColorHex = coverColorHex
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.cards = []
    }

    /// Cards in display order.
    public var orderedCards: [Flashcard] {
        cards.sorted { $0.index < $1.index }
    }

    public var cardCount: Int { cards.count }
}
