import Foundation
import SwiftData

/// A single page. Owns the serialized ink (`PKDrawing` data) and a cached
/// thumbnail. Large blobs are stored externally by SwiftData.
@Model
public final class Page {
    @Attribute(.unique) public var id: UUID
    /// Ordinal position within the owning notebook.
    public var index: Int
    public var template: PaperTemplate
    public var createdAt: Date
    public var modifiedAt: Date

    /// `PKDrawing.dataRepresentation()`. Nil/empty until first stroke.
    @Attribute(.externalStorage) public var drawingData: Data?

    /// Cached PNG thumbnail rendered from the drawing + paper background.
    @Attribute(.externalStorage) public var thumbnailData: Data?

    @Relationship(deleteRule: .nullify)
    public var notebook: Notebook?

    public init(
        id: UUID = UUID(),
        index: Int,
        template: PaperTemplate,
        notebook: Notebook? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.index = index
        self.template = template
        self.notebook = notebook
        self.createdAt = createdAt
        self.modifiedAt = createdAt
    }

    public var isBlank: Bool {
        (drawingData?.isEmpty ?? true)
    }
}
