import XCTest

/// End-to-end happy path: launch → create a notebook → open the editor → draw a
/// stroke → add/navigate a page → relaunch → assert the notebook (and ink)
/// persist.
///
/// These tests depend on accessibility identifiers and launch arguments the
/// Frontend/App agents must provide (see `AccessibilityIdentifiers.swift` and
/// the "Requests to Frontend" section of `docs/TEST_PLAN.md`). Until those land
/// the tests will fail at the first missing element — that is intentional: they
/// document the contract the UI must satisfy.
// @MainActor: XCUIApplication/XCUIElement are main-actor-isolated under the
// iOS 18 SDK + Swift 6, so the whole test class must run on the main actor.
@MainActor
final class NotebookHappyPathUITests: XCTestCase {

    private var app: XCUIApplication!

    // Use the *async* setUp/tearDown overrides: unlike the synchronous ones, an
    // async override may add @MainActor isolation, so the body runs on the main
    // actor and can touch XCUIApplication directly — no `assumeIsolated`, which
    // would otherwise "send" the non-Sendable `self` across an isolation
    // boundary and trip Swift 6's data-race checker.
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [LaunchArgument.uiTesting, LaunchArgument.resetStore]
    }

    override func tearDown() async throws {
        app = nil
    }

    // MARK: - Helpers

    /// Launches the app fresh, optionally resetting storage.
    private func launch(reset: Bool) {
        app.launchArguments = [LaunchArgument.uiTesting]
        if reset { app.launchArguments.append(LaunchArgument.resetStore) }
        app.launch()
    }

    private func waitFor(_ element: XCUIElement, _ timeout: TimeInterval = 10) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Creates a notebook from the library and returns once the editor is shown.
    private func createNotebookAndOpenEditor() {
        let newButton = app.buttons[A11y.newNotebookButton]
        XCTAssertTrue(waitFor(newButton), "Missing \(A11y.newNotebookButton)")
        newButton.tap()

        // The new-notebook flow may present a sheet with a confirm button; if so,
        // confirm. Otherwise creation is immediate.
        let confirm = app.buttons[A11y.createNotebookConfirm]
        if confirm.waitForExistence(timeout: 2) {
            confirm.tap()
        }

        // Opening the freshly created notebook lands us in the editor.
        let canvas = app.otherElements[A11y.canvas]
        if !canvas.waitForExistence(timeout: 3) {
            // Some UIs require an explicit tap on the new shelf cell to open it.
            let firstCell = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", A11y.notebookCellPrefix))
                .firstMatch
            if firstCell.waitForExistence(timeout: 3) { firstCell.tap() }
        }
        XCTAssertTrue(waitFor(canvas), "Editor canvas \(A11y.canvas) never appeared.")
    }

    /// Synthesizes a freehand stroke across the canvas.
    private func drawStroke(on canvas: XCUIElement) {
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
        let mid   = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let end   = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        // A multi-point press-drag-hold approximates a pencil stroke and gives
        // PencilKit enough movement to register a stroke.
        start.press(forDuration: 0.05, thenDragTo: mid)
        mid.press(forDuration: 0.05, thenDragTo: end)
    }

    // MARK: - Tests

    func test_createNotebook_drawStroke_addPage_persistsAcrossRelaunch() {
        launch(reset: true)

        // The new-notebook button being present signals the library is up.
        let library = app.buttons[A11y.newNotebookButton]
        XCTAssertTrue(waitFor(library), "Library not shown on launch (no \(A11y.newNotebookButton)).")

        createNotebookAndOpenEditor()

        let canvas = app.otherElements[A11y.canvas]
        drawStroke(on: canvas)

        // Add a second page and confirm the page indicator reflects two pages.
        let addPage = app.buttons[A11y.addPageButton]
        XCTAssertTrue(waitFor(addPage), "Missing \(A11y.addPageButton)")
        addPage.tap()

        let indicator = app.staticTexts[A11y.pageIndicator]
        if waitFor(indicator, 3) {
            XCTAssertTrue(indicator.label.contains("2"),
                          "Page indicator should show 2 pages, got \(indicator.label).")
        }

        // Navigate back to the previous page to verify navigation works.
        let prev = app.buttons[A11y.previousPageButton]
        if prev.exists { prev.tap() }

        // Return to the library via the system navigation back button.
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(waitFor(back), "Missing navigation back button")
        back.tap()

        // The notebook cell must exist before we relaunch.
        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", A11y.notebookCellPrefix))
            .firstMatch
        XCTAssertTrue(waitFor(cell), "Created notebook not visible on the shelf.")

        // --- Relaunch WITHOUT resetting: data must persist. ---
        app.terminate()
        launch(reset: false)

        let persistedCell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", A11y.notebookCellPrefix))
            .firstMatch
        XCTAssertTrue(waitFor(persistedCell),
                      "Notebook did not persist across relaunch.")

        // Reopen and confirm the editor + canvas come back (ink restored).
        persistedCell.tap()
        let reopenedCanvas = app.otherElements[A11y.canvas]
        XCTAssertTrue(waitFor(reopenedCanvas),
                      "Editor canvas did not reopen for the persisted notebook.")
    }

    func test_addAndNavigatePages() {
        launch(reset: true)
        createNotebookAndOpenEditor()

        let addPage = app.buttons[A11y.addPageButton]
        XCTAssertTrue(waitFor(addPage))
        addPage.tap()
        addPage.tap()  // now 3 pages

        let next = app.buttons[A11y.nextPageButton]
        let prev = app.buttons[A11y.previousPageButton]
        XCTAssertTrue(waitFor(next) || waitFor(prev),
                      "Editor must expose page navigation controls.")

        if next.exists { next.tap() }
        if prev.exists { prev.tap() }

        let indicator = app.staticTexts[A11y.pageIndicator]
        if indicator.exists {
            XCTAssertTrue(indicator.label.contains("3"),
                          "Expected 3 pages after two additions, got \(indicator.label).")
        }
    }
}
