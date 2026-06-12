# Project Outline — GoodNotes Replacement

A personal, iPad-only handwriting notebook app matching GoodNotes' core
experience, deliberately **excluding** all AI/ML features (no AI search, no
math/handwriting AI assist, no smart suggestions).

---

## 1. Goals & Non-Goals

### Goals
- A fast, low-latency Apple Pencil writing experience on iPad.
- Organize work into **folders → notebooks → pages**.
- Multiple paper templates (blank, lined, grid, dotted) and sizes (A4, A5, Letter, square).
- Core tools: pen, pencil, marker, highlighter, eraser, lasso (select/move/resize/delete).
- Per-notebook default template; per-page template override.
- Page operations: add, delete, duplicate, reorder.
- Notebook operations: create, rename, duplicate, delete, move between folders.
- Library shelf with cover + page thumbnails.
- Fully **local** (on-device) storage — your data never leaves the iPad.

### Non-Goals (explicitly out)
- ❌ Any AI features (AI search, handwriting recognition/OCR, math assist, etc.).
- ❌ Cloud sync / accounts / sharing servers (local-only by decision).
- ❌ iPhone / Mac targets (iPad only).
- ❌ Real-time collaboration.

### Deferred (post-MVP, see §7)
- PDF import & annotation, image insertion, text boxes, export/share,
  full-text *non-AI* indexing of typed text, app settings/themes, page templates gallery.

---

## 2. Platform & Tech Stack

| Concern | Choice | Notes |
|---|---|---|
| Min OS | iPadOS 26.5 | Newest SDK → modern SwiftUI, SwiftData, Observation |
| Devices | iPad only | `TARGETED_DEVICE_FAMILY = 2` |
| Language | Swift 6 | `SWIFT_STRICT_CONCURRENCY = complete` |
| UI | SwiftUI | UIKit bridging via `UIViewRepresentable` for PencilKit |
| Ink | PencilKit | `PKCanvasView`, `PKToolPicker`/custom palette, `PKDrawing` |
| Data | SwiftData | `@Model` graph, local `ModelContainer` (no CloudKit) |
| Large blobs | `@Attribute(.externalStorage)` | Ink + thumbnails stored as files by SwiftData |
| Project gen | XcodeGen | `project.yml` → `.xcodeproj` |
| CI | GitHub Actions | `xcodebuild` build + test on macOS runner |

---

## 3. Architecture (layered)

```
            ┌────────────────────────────────────────────┐
            │            App (entry, ModelContainer)       │
            └───────────────┬──────────────────────────────┘
                            │ injects DocumentStore + ThumbnailService
        ┌───────────────────┼───────────────────────────────┐
        ▼                   ▼                                 ▼
   Features (UI)        Canvas (engine)                  Persistence
   - LibraryView        - PencilKitCanvasView            - SwiftDataDocumentStore
   - NotebookEditor     - PaperRenderer                  - FileStorage
   - ToolbarView        - ToolMapper (InkTool→PKTool)    - ThumbnailService impl
   - Page navigator     - PKThumbnailService             - Seed/migration
        │                   │                                 │
        └─────────► depends on ◄─────────────────────────────┘
                            │
                    Core (shared contracts)
        Models: Folder, Notebook, Page  (SwiftData @Model)
        Types:  PaperTemplate, PaperSize, InkTool, …
        Protocols: DocumentStore, ThumbnailService
        AppSchema, InMemoryDocumentStore (preview/test double)
```

**Dependency rule:** `Core` depends on nothing app-specific. `Persistence`,
`Canvas`, and `Features` depend only on `Core` (and system frameworks) — never on
each other's internals. They meet only through the protocols in `Core`. This is
what lets three agents work in parallel without colliding.

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for data flow and the autosave loop.

---

## 4. Domain Model

- **Folder** — name, timestamps, `sortIndex`, self-referential `parent`/`subfolders`, `notebooks`. Cascade delete.
- **Notebook** — title, cover color, `defaultTemplate`, `folder?`, ordered `pages`. Cascade delete of pages.
- **Page** — `index`, `template` (override), `drawingData` (`PKDrawing`), cached `thumbnailData`.

Value types: `PaperTemplate` (style/size/orientation/colors/spacing), `InkTool`
(kind/color/width/eraser), `ColorSwatches`.

All defined in `Sources/Core` (already scaffolded).

---

## 5. Feature Breakdown (MVP)

### 5.1 Library / Shelf
- Grid of notebooks with cover + first-page thumbnail, title, page count.
- Folder navigation (breadcrumb or sidebar), create/rename/delete/move.
- New notebook flow → pick title + default template → opens editor.
- Context menu: rename, duplicate, move, delete.

### 5.2 Notebook Editor
- Full-screen `PKCanvasView` per page over a rendered paper background.
- Toolbar: tool picker (pen/pencil/marker/highlighter/eraser/lasso), color
  swatches + custom color, width selector, undo/redo.
- Page navigation: swipe or scroll between pages, page thumbnail strip/overview.
- Add page (after current / at end), with template choice; delete/duplicate/reorder.
- Zoom & pan; two-finger scroll; ruler (post-MVP optional).
- Autosave drawing on change (debounced) → `DocumentStore.updateDrawing`.

### 5.3 Paper Rendering
- Deterministic vector drawing of blank/lined/grid/dotted backgrounds from a
  `PaperTemplate`, used both live (under the canvas) and for thumbnails.

### 5.4 Persistence & Thumbnails
- SwiftData store; CRUD with correct ordering + cascade.
- Debounced thumbnail regeneration after edits; cache on `Page`.

---

## 6. Milestones

| # | Milestone | Contents |
|---|---|---|
| M0 | **Foundation** ✅ | Repo, project.yml, Core models/protocols, docs, CI skeleton |
| M1 | Backend vertical | SwiftDataDocumentStore + FileStorage + thumbnail caching + tests |
| M1 | Canvas engine | PencilKit wrapper, ToolMapper, PaperRenderer, PKThumbnailService |
| M1 | Library UI | Shelf grid, folders, new-notebook flow (against `InMemoryDocumentStore`) |
| M2 | Editor UI | Canvas integration, toolbar, page nav, autosave |
| M2 | Integration | Wire real store + thumbnail service; end-to-end create→write→reopen |
| M3 | QA hardening | Unit coverage on store/ordering, UI smoke tests, performance pass |

---

## 7. Post-MVP Backlog
PDF import/annotation · image insert · text boxes · export (PDF/image) ·
non-AI text search · settings & dark paper themes · template gallery ·
trash/restore · favorites · Files app document browser integration ·
Stage Manager / external display polish.

---

## 8. Risks & Mitigations
- **Pencil latency / large drawings** → keep one `PKCanvasView` per visible page; lazy-load pages; offload thumbnail rasterization off the main run loop where possible.
- **SwiftData ordered relationships** → use explicit `index`/`sortIndex` integers (done) rather than relying on array order.
- **Build only on real Xcode** → CI uses `xcodebuild`; this scaffolding can't compile under Command Line Tools.
- **Parallel agents colliding** → strict directory ownership + Core-only contracts (see AGENT_TASKS).
