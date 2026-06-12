import SwiftUI

// Injects the document/thumbnail services into the SwiftUI environment.
//
// Uses the `@Entry` macro (iOS 17+) which generates the backing
// `EnvironmentKey` and evaluates the default lazily on the main actor — so the
// `@MainActor`-isolated `InMemoryDocumentStore` / `PKThumbnailService` defaults
// are constructed safely. The orchestrator overrides these at the App root with
// the real `SwiftDataDocumentStore` + `PKThumbnailService`.
public extension EnvironmentValues {
    /// The document store driving all library/editor mutations. Defaults to a
    /// seeded in-memory store so previews and a not-yet-wired app still run.
    @Entry var documentStore: any DocumentStore = InMemoryDocumentStore(seed: true)

    /// Service that rasterizes paper + ink into thumbnails.
    @Entry var thumbnailService: any ThumbnailService = PKThumbnailService()
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
