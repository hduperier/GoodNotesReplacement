# Features + Canvas (Agent B — Frontend / UI)

SwiftUI screens and the PencilKit canvas engine for the GoodNotes Replacement
app. Built and previewed entirely against `InMemoryDocumentStore` +
`PKThumbnailService`, so this layer does not depend on the Persistence agent.

> **Module note:** `project.yml` compiles `App/` + all of `Sources/` into a
> **single** application target (no separate `Core`/`Canvas`/`Features`
> Swift modules, despite `ARCHITECTURE.md`'s logical layering). These files
> therefore use **no** `import Core` / `import Canvas` / `import Features`
> statements — the `public` access on Core types is harmless within one module.
> Directory ownership is still respected; only the physical module boundary
> differs from the doc.

## Canvas engine (`Sources/Canvas/`)

| File | Purpose |
|---|---|
| `PencilKitCanvasView.swift` | `UIViewRepresentable` over `PKCanvasView`. Loads `PKDrawing` from `drawingData`, applies the current tool, reports edits via a **0.7s-debounced** callback returning `PKDrawing.dataRepresentation()`. Reloads only when `pageID` changes. Pinch-zoom (1–4×) + pan. `UndoController` bridges the canvas `undoManager` to the toolbar. Flushes pending edits on teardown / page switch. |
| `ToolMapper.swift` | `InkTool` → `PKInkingTool`/`PKEraserTool`/`PKLassoTool`. Highlighter = `.marker` ink at 0.4 alpha + wide width. Eraser vector vs bitmap. Includes `UIColor(hex:)` (parses `#RRGGBB` / `#RRGGBBAA`) and `UIColor.hexString`. |
| `PaperRenderer.swift` | Draws a `PaperTemplate` background (blank/lined/grid/dotted, plus cornell/isometric) into a `CGContext`, sized to `template.canvasSize`. Reused live and for thumbnails. `image(for:scale:)` convenience. |
| `PKThumbnailService.swift` | `ThumbnailService` impl. Aspect-fits the page into the requested size, composites `PaperRenderer` background + the rasterized `PKDrawing`, returns PNG. |

## Features (`Sources/Features/`)

| File | Screen / role |
|---|---|
| `Shared/Environment+Stores.swift` | `@Environment(\.documentStore)` / `\.thumbnailService` keys. Defaults: seeded `InMemoryDocumentStore` and `PKThumbnailService` for previews + standalone runs. `.documentStore(_:)` / `.thumbnailService(_:)` view modifiers for injection. |
| `Shared/Color+Hex.swift` | `Color(hex:)` bridging the Canvas `UIColor(hex:)` parser into SwiftUI. |
| `Shared/PageThumbnailView.swift` | Renders a page from its cached `thumbnailData`, falling back to a live `ThumbnailService` render. |
| `Library/LibraryRootView.swift` | iPad `NavigationSplitView` shell — sidebar (Library + root folders) + detail shelf. **This is what `RootView` presents.** |
| `Library/LibraryView.swift` | Shelf grid: folder tiles + notebook cards, folder drill-down, new-notebook / new-folder, context menus (rename / duplicate / move / delete). |
| `Library/NotebookCardView.swift` | Notebook tile (cover spine + first-page thumbnail + title + page count). |
| `Library/NewNotebookView.swift` | New-notebook sheet: title, cover color, template picker. |
| `Library/TemplatePickerView.swift` | Reusable paper-template grid with live `Canvas` swatches. |
| `Library/MoveNotebookView.swift` | Move-to-folder sheet (root + all folders). |
| `Editor/NotebookEditorView.swift` | Paged canvas over the paper background; wires the debounced change callback to `DocumentStore.updateDrawing`; page nav (side chevrons + strip), add/delete/duplicate/reorder. |
| `Editor/ToolbarView.swift` | Tool picker, color swatches + custom `ColorPicker`, width control, eraser scope, undo/redo. |
| `Editor/PageThumbnailStrip.swift` | Horizontal page strip; tap to jump, context menu duplicate/move/delete, add-page tile. |
| `Editor/PaperBackgroundView.swift` | Live paper background via SwiftUI `Canvas` → `PaperRenderer`. |

Every screen ships a `#Preview` driven by the seeded in-memory store.

## Accessibility identifiers (for QA / UI tests)

Library / shelf:
- `library.newNotebookButton`, `library.newFolderButton`, `library.newFolderField`
- `sidebar.newFolderButton`
- `library.notebook.<UUID>` — each notebook card

New-notebook sheet:
- `newNotebook.titleField`, `newNotebook.createButton`
- `newNotebook.cover.<#HEX>` — preset cover swatches
- `template.<style>` — e.g. `template.lined`, `template.grid` (also in add-page picker)

Editor — toolbar:
- `tool.pen`, `tool.pencil`, `tool.marker`, `tool.highlighter`, `tool.eraser`, `tool.lasso`
- `tool.width`
- `color.<#HEX>` (swatches), `color.custom`
- `eraser.scope`
- `editor.undo`, `editor.redo`

Editor — canvas / pages:
- `editor.canvas` — the `PKCanvasView` (synthesize swipes here to draw)
- `editor.pageLabel`, `editor.toggleStrip`
- `editor.prevPage`, `editor.nextPage` — side-margin page navigation
- `editor.addPage`
- `editor.pageThumb.<index>` — 0-based page thumbnails

## Assumptions

- **Dual read path (real store vs. preview double).** Root folder/notebook lists
  use `@Query` so the real `SwiftDataDocumentStore` drives the UI live. When the
  injected store is the `InMemoryDocumentStore` (previews, and the not-yet-wired
  app), the view detects it via `as? InMemoryDocumentStore` and reads its plain
  arrays instead, refreshing via a `refreshToken` bumped after each mutation.
  Exactly one path is populated at a time. Nested folder contents are read from
  the relationship arrays (`folder.subfolders` / `folder.notebooks`) in both
  cases. Previews attach a throwaway `AppSchema.previewContainer()` so `@Query`
  has a container to bind to even though the data comes from the in-memory store.
- The App's `@main` injects `.modelContainer` but not the stores; the environment
  defaults keep everything runnable until the orchestrator injects
  `SwiftDataDocumentStore` + `PKThumbnailService` at the root.
- `PKCanvasView.drawingPolicy = .anyInput` so QA's synthesized finger swipes draw.
- Highlighter renders as marker ink at 0.4 alpha (no dedicated PencilKit
  highlighter ink type is assumed).
- Mutation errors are swallowed (`try?`) in this MVP UI; a fuller build would
  surface them. No data-loss path — the store remains consistent.

## CONTRACT-CHANGE notes

None. No `Sources/Core` contract needed changing; no Core files were edited. The
only deviation from the docs is the single-target module layout (see Module note
above), which is dictated by `project.yml`, not by Core.
