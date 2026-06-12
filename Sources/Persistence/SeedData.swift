import Foundation
import SwiftData

/// Populates a fresh store with a small sample library for first launch and
/// previews. Idempotent: it only seeds when the store is empty, so it is safe
/// to call on every launch.
@MainActor
public enum SeedData {

    /// Seeds a sample folder and a couple of notebooks if — and only if — the
    /// store currently has no folders and no notebooks.
    ///
    /// - Parameter store: the document store to populate.
    /// - Throws: `DocumentStoreError` if the emptiness check or any mutation fails.
    public static func seedIfEmpty(into store: DocumentStore, context: ModelContext) throws {
        guard try isEmpty(context) else { return }

        let school = try store.createFolder(name: "School", parent: nil)
        try store.createNotebook(title: "Lecture Notes", in: school, template: .lined)
        try store.createNotebook(title: "Sketchbook", in: nil, template: .dotted)
    }

    /// True when the store contains no folders and no notebooks.
    private static func isEmpty(_ context: ModelContext) throws -> Bool {
        do {
            var folders = FetchDescriptor<Folder>()
            folders.fetchLimit = 1
            var notebooks = FetchDescriptor<Notebook>()
            notebooks.fetchLimit = 1
            let folderCount = try context.fetchCount(folders)
            let notebookCount = try context.fetchCount(notebooks)
            return folderCount == 0 && notebookCount == 0
        } catch {
            throw DocumentStoreError.persistenceFailure(error.localizedDescription)
        }
    }
}
