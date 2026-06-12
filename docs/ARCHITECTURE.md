# Architecture Notes

## Module boundaries & ownership

| Module | Path | Owner | May import |
|---|---|---|---|
| Core | `Sources/Core` | shared (locked) | Foundation, SwiftData, CoreGraphics |
| Persistence | `Sources/Persistence` | Backend agent | Core, SwiftData, Foundation |
| Canvas | `Sources/Canvas` | Frontend agent | Core, PencilKit, SwiftUI, UIKit |
| Features | `Sources/Features` | Frontend agent | Core, Canvas, SwiftUI, SwiftData |
| App | `App` | shared (locked) | everything |
| Tests | `Tests` | QA agent | all targets under test |

**Core is frozen during parallel work.** If a contract must change, it is a
coordination event — note it in the PR/commit and update both sides.

## Key contracts (in Core)

- `DocumentStore` (`@MainActor`) — all non-trivial mutations (create/delete/
  duplicate/move/reorder + `updateDrawing`). UI depends on this protocol, not on
  `SwiftDataDocumentStore`.
- `ThumbnailService` (`@MainActor`) — rasterizes `PKDrawing` + paper to PNG.
  Implemented in Canvas (needs PencilKit), consumed by Persistence.
- `AppSchema` — single source of truth for the `ModelContainer` model list.
- `InMemoryDocumentStore` — preview/test double so Frontend & QA don't block on Backend.

## Dependency wiring (App)

```
GoodNotesReplacementApp
  ├─ builds ModelContainer(for: AppSchema.schema)         // local-only config
  ├─ creates ThumbnailService = PKThumbnailService()      // Canvas
  ├─ creates DocumentStore = SwiftDataDocumentStore(      // Persistence
  │       context: container.mainContext,
  │       thumbnails: thumbnailService)
  └─ injects both into the SwiftUI environment for Features
```

Injection uses SwiftUI `@Environment` custom keys (define in
`Sources/Features/Shared/Environment+Stores.swift`, Frontend-owned). Until the
real store is wired, Features read `InMemoryDocumentStore` for previews.

## Drawing & autosave loop

```
PKCanvasView delegate: canvasViewDrawingDidChange
        │  (debounce ~0.7s of idle)
        ▼
DocumentStore.updateDrawing(page, drawingData)
        │  writes Page.drawingData, bumps modifiedAt, saves
        ▼
ThumbnailService.renderThumbnail(...)  → Page.thumbnailData (async, low priority)
        │
        ▼
Library shelf observes Page via @Query and refreshes the thumbnail
```

Rules:
- One live `PKCanvasView` per *visible* page; off-screen pages render from the
  cached thumbnail until scrolled into view.
- Coordinates are template-relative (`PaperTemplate.canvasSize`) so a page looks
  identical regardless of device scale/zoom.
- Never block the main actor on thumbnail rasterization during active inking;
  debounce and yield.

## Paper rendering

`PaperRenderer` (Canvas) draws backgrounds purely from a `PaperTemplate`:
- `blank` → fill background color.
- `lined` → horizontal rules every `lineSpacing` pts in `lineColorHex`.
- `grid` → horizontal + vertical lines every `lineSpacing`.
- `dotted` → dots at grid intersections.
The same renderer is reused by `PKThumbnailService` so live and thumbnail
backgrounds match exactly.

## Concurrency

- `SWIFT_STRICT_CONCURRENCY = complete`. SwiftData `@Model` access and the
  stores are `@MainActor`. Background rasterization returns `Data` (Sendable)
  and hops back to the main actor to assign `thumbnailData`.

## Testing strategy

- **CoreTests / PersistenceTests** (XCTest, in-memory `ModelContainer`): CRUD,
  cascade deletes, page ordering/reordering invariants, duplicate semantics,
  `updateDrawing` persistence.
- **UITests** (XCUITest): launch → create notebook → write a stroke → reopen →
  stroke persists; add/delete/reorder pages; folder navigation.
- CI runs both via `xcodebuild test` on an iPad simulator.
