import Foundation
import SwiftData

/// A single flashcard: a front and a back, each with typed text plus an optional
/// handwritten ink drawing (`PKDrawing` data). Large ink blobs are stored
/// externally by SwiftData.
@Model
public final class Flashcard {
    @Attribute(.unique) public var id: UUID
    /// Ordinal position within the owning set.
    public var index: Int
    public var createdAt: Date
    public var modifiedAt: Date

    /// Typed text for each side. Empty until the user types something.
    public var frontText: String
    public var backText: String

    /// Optional `PKDrawing.dataRepresentation()` per side. Nil when the side has
    /// no ink.
    @Attribute(.externalStorage) public var frontDrawingData: Data?
    @Attribute(.externalStorage) public var backDrawingData: Data?

    @Relationship(deleteRule: .nullify)
    public var set: FlashcardSet?

    public init(
        id: UUID = UUID(),
        index: Int,
        frontText: String = "",
        backText: String = "",
        set: FlashcardSet? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.index = index
        self.frontText = frontText
        self.backText = backText
        self.set = set
        self.createdAt = createdAt
        self.modifiedAt = createdAt
    }

    /// A card with no text and no ink on either side.
    public var isBlank: Bool {
        frontText.isEmpty && backText.isEmpty
            && (frontDrawingData?.isEmpty ?? true)
            && (backDrawingData?.isEmpty ?? true)
    }
}
