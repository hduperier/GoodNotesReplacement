# GoodNotes Replacement (working title)

A native, iPad-only handwriting & notebook app built in Swift/SwiftUI, designed
as a personal replacement for GoodNotes — **without** any AI features.

| Decision | Choice |
|---|---|
| Platform | iPadOS **26.5+**, iPad only (`TARGETED_DEVICE_FAMILY = 2`) |
| Language / UI | Swift 6, SwiftUI (+ UIKit bridging where required) |
| Ink engine | **PencilKit** (`PKCanvasView`) |
| Persistence | **Local only** — SwiftData on-device (no CloudKit, no server) |
| MVP scope | Core inking + notebook management |

## Getting started

This repo stores source + an [XcodeGen](https://github.com/yonaskolb/XcodeGen)
`project.yml` instead of a committed `.xcodeproj` (keeps diffs clean).

```bash
brew install xcodegen
xcodegen generate          # produces GoodNotesReplacement.xcodeproj
open GoodNotesReplacement.xcodeproj
```

Then set your **Development Team** in the target signing settings and run on an
iPad (or iPad simulator) running iPadOS 26.5+.

> Requires a current Xcode with the iPadOS 26.5 SDK. This project cannot be
> built with Command Line Tools alone.

## Layout

```
App/                 App entry point + root view (app target)
Sources/
  Core/              Domain models (SwiftData), value types, protocols  ← shared contracts
  Persistence/       SwiftData store, file storage, thumbnail caching   ← BACKEND
  Canvas/            PencilKit wrapper, paper rendering, tool mapping    ← FRONTEND (engine)
  Features/          SwiftUI screens: Library shelf, Notebook editor     ← FRONTEND (UI)
Tests/               Unit + UI tests                                     ← QA
docs/                Outline, architecture, and per-agent task briefs
```

See [`docs/PROJECT_OUTLINE.md`](docs/PROJECT_OUTLINE.md) for the full plan and
[`docs/AGENT_TASKS.md`](docs/AGENT_TASKS.md) for the divide-and-conquer breakdown.
