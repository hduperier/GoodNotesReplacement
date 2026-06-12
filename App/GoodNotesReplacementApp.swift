import SwiftUI
import SwiftData

@main
struct GoodNotesReplacementApp: App {
    private let container: ModelContainer
    private let store: SwiftDataDocumentStore
    private let thumbnails: ThumbnailService

    init() {
        let arguments = CommandLine.arguments
        let isUITesting = arguments.contains("-uitesting")
        let shouldReset = arguments.contains("-uitest-reset-store")

        // Deterministic UI-test runs can wipe the on-disk store before launch.
        if shouldReset {
            Self.eraseLocalStore()
        }

        do {
            container = try ModelContainerFactory.makeLocalContainer()
        } catch {
            fatalError("Unable to create ModelContainer: \(error)")
        }

        let thumbnailService = PKThumbnailService()
        self.thumbnails = thumbnailService
        self.store = SwiftDataDocumentStore(
            context: container.mainContext,
            thumbnails: thumbnailService
        )

        // Seed first-launch sample content — but never under UI testing, where
        // tests expect a clean, empty library.
        if !isUITesting {
            try? SeedData.seedIfEmpty(into: store, context: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .documentStore(store)
                .thumbnailService(thumbnails)
        }
        .modelContainer(container)
    }

    /// Removes the local SwiftData store files (SQLite + WAL/SHM sidecars) so a
    /// UI test starts from an empty library. Matches the store name used by
    /// `ModelContainerFactory`.
    private static func eraseLocalStore() {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }

        let base = ModelContainerFactory.storeName
        for suffix in [".store", ".store-wal", ".store-shm"] {
            let url = support.appendingPathComponent(base + suffix)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
