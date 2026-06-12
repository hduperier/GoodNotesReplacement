import Foundation
import SwiftData

/// Builds the local-only `ModelContainer` for the persisted document graph.
///
/// This is the single place the app (and tests/previews) construct a container,
/// keeping the configuration — name, storage location, no CloudKit — consistent
/// with `App/GoodNotesReplacementApp.swift`.
@MainActor
public enum ModelContainerFactory {

    /// The on-disk store name. Matches the configuration the App uses so both
    /// resolve to the same file in Application Support.
    public static let storeName = "GoodNotesReplacement"

    /// Builds the production, on-device, local-only container.
    ///
    /// No CloudKit and no remote sync: the store is a plain SQLite file in the
    /// app's Application Support directory.
    /// - Throws: any error from `ModelContainer` initialization.
    public static func makeLocalContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AppSchema.schema,
            configurations: ModelConfiguration(storeName)
        )
    }

    /// Builds a throwaway in-memory container for previews and unit tests.
    ///
    /// Nothing is written to disk; the graph is discarded when the container is
    /// released.
    /// - Throws: any error from `ModelContainer` initialization.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AppSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
