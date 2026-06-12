# Divide-and-Conquer: Agent Task Briefs

Three agents work in parallel against the frozen `Sources/Core` contracts.
**Strict directory ownership** prevents collisions — only edit files under your
paths. XcodeGen globs directories, so adding files needs no `project.yml` edits.

Do **not** edit `Sources/Core`, `App/`, or `project.yml` (shared/locked). If you
believe a Core contract is wrong, leave a `// CONTRACT-CHANGE:` note and flag it
rather than editing Core.

---

## Agent A — Backend (Persistence)

**Owns:** `Sources/Persistence/**`, `Tests/PersistenceTests/**` (impl-side fixtures)

**Deliverables**
1. `SwiftDataDocumentStore: DocumentStore` — full implementation of every method
   in the protocol, using an injected `ModelContext`.
   - Correct `sortIndex`/`index` maintenance on create/move/delete/duplicate.
   - Cascade behavior consistent with the model `deleteRule`s.
   - `createNotebook` seeds exactly one blank `Page` with the given template.
   - `addPage(after:)` inserts at `page.index + 1` and shifts following pages.
   - `duplicatePage` / `duplicateNotebook` deep-copy ink data and re-index.
   - `updateDrawing` writes `drawingData`, bumps `modifiedAt`, then asks the
     injected `ThumbnailService` to refresh `thumbnailData` (don't block inking).
   - `save()` wraps `context.save()` and maps errors to `DocumentStoreError`.
2. `FileStorage` (optional helper) — if you choose to store any blobs outside
   SwiftData; otherwise rely on `@Attribute(.externalStorage)` and document that.
3. `SeedData` — a helper that populates a fresh store with a sample folder +
   notebook for first-launch and previews.
4. A `ModelContainer` factory for the **local-only** config the App will call.

**Constraints**
- `@MainActor`. No PencilKit import (you receive a `ThumbnailService`).
- Inject dependencies via `init` — never reach for singletons.

**Done when:** every `DocumentStore` method is implemented and the
PersistenceTests the QA agent writes pass against an in-memory container.

---

## Agent B — Frontend / UI (Canvas + Features)

**Owns:** `Sources/Canvas/**`, `Sources/Features/**`, and the body of `App/RootView.swift`

**Deliverables — Canvas (engine)**
1. `PencilKitCanvasView: UIViewRepresentable` wrapping `PKCanvasView`; binds to a
   `Page`, loads/saves `PKDrawing` data, reports changes (debounced) to a closure.
2. `ToolMapper` — converts `InkTool` → `PKInkingTool`/`PKEraserTool`/`PKLassoTool`
   (pen/pencil/marker/highlighter widths & ink types; vector vs bitmap eraser).
3. `PaperRenderer` — draws `PaperTemplate` backgrounds (blank/lined/grid/dotted).
4. `PKThumbnailService: ThumbnailService` — composites paper + `PKDrawing` to PNG.

**Deliverables — Features (UI)**
5. `LibraryView` — shelf grid of notebooks (cover + thumbnail + title + page
   count), folder navigation, new-notebook flow, context menus
   (rename/duplicate/move/delete). Drive via the `DocumentStore` protocol.
6. `NotebookEditorView` — paged canvas, paper background, page navigation +
   thumbnail strip, add/delete/duplicate/reorder page UI.
7. `ToolbarView` — tool picker, color swatches + custom color, width, undo/redo.
8. `Environment+Stores.swift` — SwiftUI environment keys injecting `DocumentStore`
   and `ThumbnailService`; default to `InMemoryDocumentStore` for previews.
9. Replace `RootView`'s body to present `LibraryView`.

**Constraints**
- Depend only on `Core` (+ `Canvas` for Features). Use `@Query` for trivial reads
  and the `DocumentStore` protocol for mutations.
- Build/preview against `InMemoryDocumentStore` so you don't block on Agent A.
- Provide `#Preview`s for every screen.

**Done when:** the app navigates Library → Editor, you can write with the Pencil,
switch tools/colors, add/delete/reorder pages, and drawings persist via the store.

---

## Agent C — Testing / QA

**Owns:** `Tests/CoreTests/**`, `Tests/PersistenceTests/**`, `Tests/UITests/**`,
`.github/workflows/**`, `docs/TEST_PLAN.md`

**Deliverables**
1. `docs/TEST_PLAN.md` — scope, matrix, and manual smoke checklist.
2. **CoreTests** — value-type tests: `PaperTemplate.canvasSize`/orientation,
   `InkTool` defaults, schema builds, `InMemoryDocumentStore` invariants.
3. **PersistenceTests** — against an in-memory `ModelContainer`:
   - create/rename/delete folders & notebooks; cascade correctness.
   - `createNotebook` seeds one page; `addPage` ordering; `movePage` reindexing;
     `deletePage` re-index; `duplicatePage`/`duplicateNotebook` deep-copy.
   - `updateDrawing` persists data + bumps `modifiedAt`.
   - Use a stub `ThumbnailService` returning fixed `Data`.
4. **UITests** — launch, create notebook, draw a stroke (synthesize a swipe on
   the canvas), navigate pages, reopen and assert persistence; accessibility ids
   needed from Agent B should be listed in TEST_PLAN.md as requests.
5. **CI** — `.github/workflows/ci.yml`: `xcodegen generate` → `xcodebuild test`
   on an iPad simulator (iPadOS 26.5), caching where useful.

**Constraints**
- Tests target the `DocumentStore` **protocol** so they run against both
  `InMemoryDocumentStore` and `SwiftDataDocumentStore`.
- Don't edit production source to make tests pass; file requests in TEST_PLAN.md.

**Done when:** `xcodebuild test` is green in CI for Core + Persistence, and UI
smoke tests cover the create→write→persist happy path.

---

## Integration (orchestrator, after agents land)
Wire `App` to construct `PKThumbnailService` + `SwiftDataDocumentStore` and inject
them; run the end-to-end path; reconcile any `CONTRACT-CHANGE` notes.
