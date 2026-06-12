import Foundation
import SwiftData

/// A notebook: an ordered collection of pages plus cover metadata.
@Model
public final class Notebook {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date
    public var modifiedAt: Date
    /// Manual sort position within its folder (or the root library).
    public var sortIndex: Int

    /// Cover color shown on the library shelf, #RRGGBB.
    public var coverColorHex: String

    /// Default template applied to newly added pages.
    public var defaultTemplate: PaperTemplate

    @Relationship(deleteRule: .nullify)
    public var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Page.notebook)
    public var pages: [Page]

    public init(
        id: UUID = UUID(),
        title: String,
        folder: Folder? = nil,
        defaultTemplate: PaperTemplate = .blankWhite,
        coverColorHex: String = "#4E6E8E",
        sortIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.folder = folder
        self.defaultTemplate = defaultTemplate
        self.coverColorHex = coverColorHex
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.pages = []
    }

    /// Pages in display order.
    public var orderedPages: [Page] {
        pages.sorted { $0.index < $1.index }
    }

    public var pageCount: Int { pages.count }
}
