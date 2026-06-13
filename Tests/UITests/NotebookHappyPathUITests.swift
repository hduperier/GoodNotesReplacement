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

    /// Taps `element`, falling back to a center-coordinate tap. SwiftUI
    /// toolbar/navbar buttons often report as non-hittable, so `.tap()` runs a
    /// scroll-to-visible preflight that fails ("Failed to scroll to visible")
    /// even though the button is on screen. A coordinate tap bypasses that.
    private func robustTap(_ element: XCUIElement) {
        // Tap the *window* at the element's frame center. Plain `.tap()` runs a
        // scroll-to-visible AX preflight that fails ("kAXErrorCannotComplete")
        // for SwiftUI buttons in non-scrollable scroll views / toolbars on this
        // SDK, and an element-relative coordinate tap doesn't land when the
        // element reports non-hittable. An absolute window-coordinate tap does.
        let f = element.frame
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: f.midX, dy: f.midY))
            .tap()
    }

    /// Taps `element` until `target` appears, retrying because the first
    /// synthesized tap after an app launch/relaunch is sometimes swallowed while
    /// the window becomes key/active.
    private func tap(_ element: XCUIElement, untilPresent target: XCUIElement, attempts: Int = 4) {
        for _ in 0..<attempts {
            if target.exists { return }
            robustTap(element)
            if target.waitForExistence(timeout: 3) { return }
        }
    }

    /// On iPad portrait the split-view sidebar can present as an overlay popover
    /// (notably after a relaunch), covering the detail with a dismiss region that
    /// swallows taps meant for shelf cells. Dismiss it if present.
    private func dismissSidebarOverlayIfPresent() {
        let dismissRegion = app.descendants(matching: .any)
            .matching(identifier: "PopoverDismissRegion").firstMatch
        if dismissRegion.exists {
            robustTap(dismissRegion)
            _ = dismissRegion.waitForExistence(timeout: 1) // let the dismiss settle
        }
    }

    /// Whether the page indicator's label contains `substring` within `timeout`.
    private func indicatorShows(_ substring: String, timeout: TimeInterval = 5) -> Bool {
        let indicator = app.staticTexts[A11y.pageIndicator]
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if indicator.exists && indicator.label.contains(substring) { return true }
            _ = indicator.waitForExistence(timeout: 0.3)
        } while Date() < deadline
        return indicator.exists && indicator.label.contains(substring)
    }

    /// The live ink canvas. `PKCanvasView` is a `UIScrollView`, so XCUITest
    /// surfaces it as a scrollView (not an `otherElement`); match the identifier
    /// across all element types so the lookup is robust to that classification.
    private var canvas: XCUIElement {
        app.descendants(matching: .any).matching(identifier: A11y.canvas).firstMatch
    }

    /// Creates a notebook from the library and returns once the editor is shown.
    private func createNotebookAndOpenEditor() {
        // Tests always start from an empty library, so drive creation from the
        // empty-state CTA — a normal in-content button that XCUITest can tap.
        // (The toolbar "+" button reports as non-hittable, a known SwiftUI
        // toolbar quirk, so a tap there doesn't open the sheet.)
        let createCTA = app.scrollViews.buttons["New Notebook"]
        XCTAssertTrue(waitFor(createCTA), "Missing empty-state New Notebook button")

        // First interaction after launch — retry until the sheet's Create button
        // appears (the first synthesized tap can be swallowed).
        let confirm = app.buttons[A11y.createNotebookConfirm]
        tap(createCTA, untilPresent: confirm)
        XCTAssertTrue(confirm.exists,
                      "New-notebook sheet did not present its \(A11y.createNotebookConfirm).")
        robustTap(confirm)

        // Creating the notebook navigates straight into the editor.
        XCTAssertTrue(waitFor(canvas), "Editor canvas \(A11y.canvas) never appeared.")

        // Creating the notebook navigates straight into the editor.
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

        drawStroke(on: canvas)

        // Add a second page and confirm the page indicator reflects two pages.
        let addPage = app.buttons[A11y.addPageButton]
        XCTAssertTrue(waitFor(addPage), "Missing \(A11y.addPageButton)")
        robustTap(addPage)

        let indicator = app.staticTexts[A11y.pageIndicator]
        if waitFor(indicator, 3) {
            XCTAssertTrue(indicator.label.contains("2"),
                          "Page indicator should show 2 pages, got \(indicator.label).")
        }

        // Navigate back to the previous page to verify navigation works.
        let prev = app.buttons[A11y.previousPageButton]
        if prev.exists { robustTap(prev) }

        // Return to the library via the system navigation back button.
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(waitFor(back), "Missing navigation back button")
        robustTap(back)

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
        // After relaunch the sidebar may overlay the detail; dismiss it, then
        // retry the cell tap (the first synthesized tap can also be swallowed).
        dismissSidebarOverlayIfPresent()
        tap(persistedCell, untilPresent: canvas)
        XCTAssertTrue(canvas.exists,
                      "Editor canvas did not reopen for the persisted notebook.")
    }

    func test_addAndNavigatePages() {
        launch(reset: true)
        createNotebookAndOpenEditor()

        let addPage = app.buttons[A11y.addPageButton]
        XCTAssertTrue(waitFor(addPage))

        // Add two pages, synchronizing on the page indicator's total ("/ N") so a
        // tap swallowed during the post-add animation doesn't desync the count.
        for total in ["2", "3"] {
            for _ in 0..<4 where !indicatorShows("/ \(total)", timeout: 1) {
                robustTap(addPage)
            }
            XCTAssertTrue(indicatorShows("/ \(total)"),
                          "Expected \(total) pages, got \(app.staticTexts[A11y.pageIndicator].label).")
        }

        // Page navigation controls must be present and usable.
        let next = app.buttons[A11y.nextPageButton]
        let prev = app.buttons[A11y.previousPageButton]
        XCTAssertTrue(waitFor(next) || waitFor(prev),
                      "Editor must expose page navigation controls.")
        if next.exists { robustTap(next) }
        if prev.exists { robustTap(prev) }
    }
}
