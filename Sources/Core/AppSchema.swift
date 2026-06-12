import Foundation
import SwiftData

/// Single source of truth for the persisted model graph. The Persistence layer
/// and previews build their `ModelContainer` from this.
public enum AppSchema {
    public static let models: [any PersistentModel.Type] = [
        Folder.self,
        Notebook.self,
        Page.self,
    ]

    public static var schema: Schema { Schema(models) }

    /// A throwaway in-memory container, handy for SwiftUI previews and tests.
    @MainActor
    public static func previewContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
