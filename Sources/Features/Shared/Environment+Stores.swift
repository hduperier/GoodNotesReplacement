import SwiftUI

// Injects the document/thumbnail services into the SwiftUI environment.
//
// Uses the `@Entry` macro (iOS 17+) to generate the backing `EnvironmentKey`.
// The defaults construct `@MainActor`-isolated types, so under Swift 6 strict
// concurrency we wrap them in `MainActor.assumeIsolated` — SwiftUI always reads
// environment defaults on the main actor, so the assumption holds. The
// orchestrator overrides these at the App root with the real
// `SwiftDataDocumentStore` + `PKThumbnailService`.
public extension EnvironmentValues {
    /// The document store driving all library/editor mutations. Defaults to a
    /// seeded in-memory store so previews and a not-yet-wired app still run.
    @Entry var documentStore: any DocumentStore = MainActor.assumeIsolated { InMemoryDocumentStore(seed: true) }

    /// Service that rasterizes paper + ink into thumbnails.
    @Entry var thumbnailService: any ThumbnailService = MainActor.assumeIsolated { PKThumbnailService() }
}

public extension View {
    /// Injects a concrete `DocumentStore` into the environment.
    func documentStore(_ store: any DocumentStore) -> some View {
        environment(\.documentStore, store)
    }

    /// Injects a concrete `ThumbnailService` into the environment.
    func thumbnailService(_ service: any ThumbnailService) -> some View {
        environment(\.thumbnailService, service)
    }
}
