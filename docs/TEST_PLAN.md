# Test Plan — GoodNotes Replacement

Owner: Agent C (Testing / QA). Targets iPadOS 26.5, iPad-only, Swift 6 strict
concurrency, SwiftUI + PencilKit, **local-only** SwiftData. MVP scope = core
inking + notebook management.

> This machine has no iOS SDK, so tests are authored and self-reviewed but not
> compiled here. CI (`.github/workflows/ci.yml`) is the source of truth for green.

## 1. Scope

In scope for the MVP test effort:

- **Value types** (`Core/Types`): `PaperTemplate` / `PaperSize` / `PaperStyle` /
  `PaperOrientation`, `InkTool` / `InkToolKind` / `EraserKind`, `ColorSwatches`.
- **Schema** (`Core/AppSchema`): schema builds, preview container is usable and
  isolated, model-level cascade deletes.
- **DocumentStore contract**: a single reusable suite (`DocumentStoreContractTests`)
  exercised against **both** `InMemoryDocumentStore` (Core) and
  `SwiftDataDocumentStore` (Persistence, in-memory `ModelContainer`).
- **Persistence specifics**: page seeding, thumbnail-refresh wiring, persistence
  across a fresh `ModelContext`.
- **UI happy path** (XCUITest): launch → create notebook → draw a stroke → add /
  navigate pages → relaunch → assert persistence.

Out of scope for MVP: PencilKit rendering fidelity, `PaperRenderer` pixel output,
`ToolMapper` (Canvas-owned; can be added once Frontend lands), CloudKit/sync
(explicitly local-only), performance benchmarks.

## 2. Test matrix

| Area | Type | Where | Driven against |
|---|---|---|---|
| `PaperSize.pointSize`, `canvasSize` portrait/landscape across all sizes | Unit | `CoreTests/PaperTemplateTests` | value type |
| `PaperTemplate` builtIns + Codable round-trips; enum raw-value stability | Unit | `CoreTests/PaperTemplateTests` | value type |
| `InkTool` defaults/presets + Codable/Hashable; `ColorSwatches.starter` | Unit | `CoreTests/InkToolTests` | value type |
| `AppSchema.schema` entities; `previewContainer()` usable + isolated; cascade | Unit | `CoreTests/AppSchemaTests` | `ModelContainer` |
| `InMemoryDocumentStore` invariants (roots, seed, schema, save no-op) | Unit | `CoreTests/InMemoryDocumentStoreTests` | in-memory store |
| Folder CRUD + cascade; notebook CRUD + cascade; create seeds 1 page | Integration | `PersistenceTests/DocumentStoreContractTests` | **both** stores |
| `addPage` ordering; `movePage` contiguous reindex; `deletePage` reindex | Integration | `…/DocumentStoreContractTests` | **both** stores |
| `duplicatePage` / `duplicateNotebook` deep-copy + indices | Integration | `…/DocumentStoreContractTests` | **both** stores |
| `updateDrawing` persists data + bumps `modifiedAt`; survives refetch | Integration | `…/DocumentStoreContractTests` | **both** stores |
| Static `schema` == `AppSchema.schema`; one page persisted to context | Integration | `PersistenceTests/SwiftDataDocumentStoreTests` | SwiftData store |
| `updateDrawing` triggers thumbnail refresh; tolerates renderer failure | Integration | `…/SwiftDataDocumentStoreTests` | SwiftData store + stub |
| Data survives a fresh `ModelContext` on the same container | Integration | `…/SwiftDataDocumentStoreTests` | SwiftData store |
| Create → draw → add/navigate page → relaunch persists | UI | `UITests/NotebookHappyPathUITests` | running app |

### Shared-contract design

`DocumentStoreContractTests` is an **abstract** `@MainActor XCTestCase`. Its
`makeStore()` returns `nil` in the base (inherited tests `XCTSkip`); subclasses
override it to supply a fresh store and inherit every `test…`:

- `InMemoryDocumentStoreContractTests` → `InMemoryDocumentStore`.
- `SwiftDataDocumentStoreContractTests` → `SwiftDataDocumentStore` over an
  in-memory `ModelContainer` with a `StubThumbnailService`.

Cascade/persistence assertions go through overridable read-back hooks
(`allFolderIDs` / `allNotebookIDs` / `allPageIDs` / `fetchPage`) so the suite
never reaches into a specific implementation: SwiftData uses `FetchDescriptor`,
the in-memory store walks its root arrays.

> Note: `CoreTests` and `PersistenceTests` compile into the **same** unit-test
> bundle (`GoodNotesReplacementTests`, per `project.yml`), so the in-memory
> subclass in `CoreTests/` can subclass the base class declared in
> `PersistenceTests/`. If the targets are ever split, move
> `DocumentStoreContractTests.swift` into a shared location.

## 3. Manual smoke checklist

Run on an iPad (or simulator) before tagging a build:

- [ ] Cold launch shows the library shelf (empty state on first run).
- [ ] "New notebook" creates a notebook with exactly one blank page.
- [ ] Choosing each template (Blank / Lined / Grid / Dotted) renders the correct
      background in the editor.
- [ ] Apple Pencil draws ink; finger drawing behaves per the configured palm/finger
      policy.
- [ ] Switching tools (pen / pencil / marker / highlighter / eraser / lasso) and
      colors/width updates subsequent strokes.
- [ ] Undo/redo work and stay consistent after page switches.
- [ ] Add / delete / duplicate / reorder pages; page indicator and thumbnail strip
      stay in sync; indices remain contiguous.
- [ ] Drawing autosaves (≈0.7s idle) — leave the editor and the shelf thumbnail
      updates.
- [ ] Folder create / rename / move / delete; deleting a folder removes the
      notebooks (and pages) inside it.
- [ ] Notebook rename / duplicate / move / delete; duplicate is a deep copy
      (editing the copy doesn't change the original).
- [ ] Force-quit and relaunch: notebooks, pages, ink, and folder structure all
      persist (local-only, no network).
- [ ] Rotate the device: portrait/landscape canvas sizing is correct and ink stays
      aligned (coordinates are template-relative).

## 4. Requests to Frontend / App (blockers for UI tests)

The XCUITests reference identifiers and launch arguments centralized in
`Tests/UITests/AccessibilityIdentifiers.swift`. Frontend/App must apply these
exact strings (and confirm/adjust in `Sources/Features/README.md`):

### Accessibility identifiers

| Constant | Identifier | Element |
|---|---|---|
| `A11y.library` | `library.root` | Library shelf root container |
| `A11y.newNotebookButton` | `library.newNotebookButton` | Start new-notebook flow |
| `A11y.createNotebookConfirm` | `library.createNotebookConfirm` | Confirm in the new-notebook sheet (if any) |
| `A11y.notebookCellPrefix` | `library.notebookCell…` | Each shelf cell (identifier **begins with** this prefix) |
| `A11y.editor` | `editor.root` | Editor screen container |
| `A11y.canvas` | `editor.canvas` | Live ink canvas (`PKCanvasView` host) — drags synthesized here |
| `A11y.addPageButton` | `editor.addPageButton` | Add a page after current |
| `A11y.nextPageButton` | `editor.nextPageButton` | Go to next page |
| `A11y.previousPageButton` | `editor.previousPageButton` | Go to previous page |
| `A11y.pageIndicator` | `editor.pageIndicator` | Static text like `"1 / 2"` |
| `A11y.backToLibraryButton` | `editor.backButton` | Return to library |

Notes for Frontend:
- The canvas host must be an accessibility **element/container** that
  `app.otherElements["editor.canvas"]` can find and that accepts synthesized
  drags. If `PKCanvasView` isn't directly hittable, expose an
  `accessibilityIdentifier` on the hosting `UIViewRepresentable`/wrapper view.
- The page indicator label should literally contain the page count digit (e.g.
  `2` when there are two pages) for the assertions to read it.

### Launch arguments (App-owned)

| Constant | Argument | Behavior the app must honor |
|---|---|---|
| `LaunchArgument.uiTesting` | `-uitesting` | UI-test mode (e.g. disable onboarding/animations). |
| `LaunchArgument.resetStore` | `-uitest-reset-store` | Wipe the local SwiftData store on launch for a deterministic empty start. |

> Until these land, `NotebookHappyPathUITests` fail at the first missing element.
> That is intentional — they encode the UI contract. CoreTests + PersistenceTests
> do **not** depend on any of this and gate CI on their own.

## 5. Requests to Backend / Persistence

- None blocking. `SwiftDataDocumentStore(context:thumbnails:)` and
  `ModelContainerFactory` already match what the tests reference.
- If `updateDrawing`'s thumbnail refresh moves off a main-actor `Task`, update
  `SwiftDataDocumentStorePersistenceTests.test_updateDrawing_eventuallyRefreshesThumbnail`,
  which currently pumps the main run loop to await it.

## 6. Known constraints / assumptions

- No production code was modified to make tests pass (per brief). All needs are
  recorded above as requests.
- Tests compile against the real `Sources/Core` types and the documented
  `SwiftDataDocumentStore` initializer.
- `modifiedAt` bump assertions use `>=` with a tiny busy-wait, since `Date.now`
  resolution can collapse two adjacent calls to the same instant.
- CI pins `macos-15` / a chosen Xcode as a realistic default; the iPadOS 26.5
  runtime may require a newer runner image or self-hosted runner (commented in
  `ci.yml`). The destination step degrades gracefully if the exact runtime is
  absent.
