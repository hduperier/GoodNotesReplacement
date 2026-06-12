# Persistence (Agent A — Backend)

Local-only SwiftData implementation of the `Sources/Core` `DocumentStore`
contract. No CloudKit, no server. `@MainActor` throughout. Imports only
`Foundation` + `SwiftData` (no PencilKit — thumbnails go through the injected
`ThumbnailService`).

## Files

### `SwiftDataDocumentStore.swift`
`@MainActor final class SwiftDataDocumentStore: DocumentStore`.

- Injected `ModelContext` (the container `mainContext`) and `ThumbnailService`
  via `init` — no singletons.
- Implements every protocol method, mirroring `InMemoryDocumentStore`'s
  ordering / cascade / duplicate semantics:
  - `createNotebook` seeds exactly one blank `Page` at index 0 with the template.
  - `addPage(after:)` inserts at `page.index + 1` and shifts later pages up.
  - `movePage` removes + reinserts in the ordered list and reindexes `0..<n`
    contiguously; rejects out-of-range indices with `.invalidIndex`.
  - `deletePage` deletes and closes the index gap so indices stay contiguous.
  - `duplicatePage` / `duplicateNotebook` deep-copy `drawingData` +
    `thumbnailData` and re-index.
  - Deletes rely on the Core model `deleteRule`s (`.cascade` on
    `Folder.subfolders`, `Folder.notebooks`, `Notebook.pages`), so deleting a
    folder/notebook cascades to its contents — we just `context.delete(...)`.
- `updateDrawing` writes `drawingData`, bumps `modifiedAt`, saves, then refreshes
  the thumbnail off the critical path: a `Task(priority: .utility)` on the main
  actor that tolerates rasterization failures (`try?` / catch) and never blocks
  the active stroke. Uses `[weak self, weak page]` so a closed editor doesn't
  keep objects alive.
- `save()` wraps `context.save()` and maps any thrown error to
  `DocumentStoreError.persistenceFailure(_)`. Root reads
  (`rootFolders`/`rootNotebooks`) use `FetchDescriptor` + `#Predicate`
  (`parent == nil` / `folder == nil`) sorted by `sortIndex`; their fetch errors
  are also mapped to `.persistenceFailure`.

### `ModelContainerFactory.swift`
`@MainActor enum ModelContainerFactory`.

- `makeLocalContainer()` — production, on-device, local-only container built from
  `AppSchema.schema` with `ModelConfiguration("GoodNotesReplacement")`, matching
  `App/GoodNotesReplacementApp.swift`. (`storeName` is exposed as a constant.)
- `makeInMemoryContainer()` — throwaway in-memory container for tests/previews.

### `SeedData.swift`
`@MainActor enum SeedData`.

- `seedIfEmpty(into:context:)` — idempotent first-launch/preview seed. Uses
  `fetchCount` (with `fetchLimit = 1`) on `Folder` and `Notebook` and only seeds
  when both are empty: one "School" folder with a lined "Lecture Notes" notebook
  plus a dotted root "Sketchbook" — mirrors `InMemoryDocumentStore.seedSample()`.

## Integrator wiring

In `App/GoodNotesReplacementApp.swift` (or a composition root):

```swift
let container = try ModelContainerFactory.makeLocalContainer()
let thumbnails = PKThumbnailService()            // Canvas layer
let store = SwiftDataDocumentStore(
    context: container.mainContext,
    thumbnails: thumbnails
)
try SeedData.seedIfEmpty(into: store, context: container.mainContext)
// inject `store` and `thumbnails` into the SwiftUI environment (Agent B keys)
```

The App currently builds its own container inline; it can switch to
`ModelContainerFactory.makeLocalContainer()` (same config) or keep its inline one
— both resolve to the same store file.

## Assumptions

- Mutations call `save()` eagerly (matches the "writes … saves" contract and lets
  QA assert persistence without a manual `save()`). The async thumbnail task does
  its own best-effort `try? context.save()` after assigning `thumbnailData`.
- `SeedData.seedIfEmpty` needs the `ModelContext` to check emptiness because the
  `DocumentStore` protocol exposes no list/count API; the App already holds the
  context, so this is cheap to wire.
- Blobs (`drawingData`/`thumbnailData`) rely on the Core models'
  `@Attribute(.externalStorage)`; no separate `FileStorage` helper was added.

## CONTRACT-CHANGE notes

None. The existing Core contracts were sufficient.
