import Foundation

/// The accessibility identifiers the UI tests drive against. These are the
/// **requested** identifiers documented in `docs/TEST_PLAN.md` under
/// "Requests to Frontend". The Frontend agent must apply
/// `.accessibilityIdentifier(_:)` with these exact strings (and confirm/adjust
/// them in `Sources/Features/README.md`).
///
/// Keeping them in one place means a rename is a single-line change here once
/// Frontend confirms the final names.
enum A11y {

    // NOTE: These values were reconciled by the orchestrator to match the
    // identifiers the Frontend agent actually emits (see Sources/Features/*).
    // The library/editor *container* checks and the back button are driven off
    // guaranteed elements (the new-notebook button, the canvas, and the system
    // navigation bar) rather than container ids, which SwiftUI does not reliably
    // surface to XCUITest.

    // MARK: Library / shelf
    /// Button that starts the new-notebook flow. Doubles as the "library is up"
    /// signal at launch.
    static let newNotebookButton = "library.newNotebookButton"
    /// Confirm/create button in the new-notebook sheet.
    static let createNotebookConfirm = "newNotebook.createButton"
    /// A notebook cell on the shelf. Cells are identified `library.notebook.<uuid>`,
    /// so this prefix matches via `BEGINSWITH`.
    static let notebookCellPrefix = "library.notebook"

    // MARK: Editor
    /// The live ink canvas (the `PKCanvasView` host). Drags are synthesized here.
    static let canvas = "editor.canvas"
    /// Adds a page after the current one (in the page thumbnail strip).
    static let addPageButton = "editor.addPage"
    /// Navigates to the next page (side-margin overlay button).
    static let nextPageButton = "editor.nextPage"
    /// Navigates to the previous page (side-margin overlay button).
    static let previousPageButton = "editor.prevPage"
    /// Static text exposing the current page position, e.g. "1 / 2".
    static let pageIndicator = "editor.pageLabel"
}

/// Launch arguments the UI test passes to put the app in a deterministic state.
/// The App/Frontend agents must honor these (documented as requests).
enum LaunchArgument {
    /// Wipe persistent storage on launch so each UI test starts empty.
    static let resetStore = "-uitest-reset-store"
    /// Generic "we are in a UI test" flag (e.g. disable onboarding/animations).
    static let uiTesting = "-uitesting"
}
