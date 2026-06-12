import Foundation
import SwiftData

/// A library folder. Folders nest arbitrarily and contain notebooks.
@Model
public final class Folder {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    /// Manual sort position among siblings.
    public var sortIndex: Int

    @Relationship(deleteRule: .nullify, inverse: \Folder.subfolders)
    public var parent: Folder?

    @Relationship(deleteRule: .cascade)
    public var subfolders: [Folder]

    @Relationship(deleteRule: .cascade, inverse: \Notebook.folder)
    public var notebooks: [Notebook]

    public init(
        id: UUID = UUID(),
        name: String,
        parent: Folder? = nil,
        sortIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.parent = parent
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.subfolders = []
        self.notebooks = []
    }
}
