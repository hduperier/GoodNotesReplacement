import XCTest
import UIKit
@testable import GoodNotesReplacement

/// Theming contract for ink color resolution.
///
/// Policy (see `docs/TEST_PLAN.md` / `ToolMapper`): the paper is document
/// content and is always light, so **ink must not follow the system
/// appearance**. A dark-mode-adaptive color (e.g. `.label`) would resolve to
/// white on the light page and render invisible. These tests lock that in.
@MainActor
final class ToolMapperThemeTests: XCTestCase {

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    /// RGBA components of `color` resolved against `traits`.
    private func rgba(
        _ color: UIColor, _ traits: UITraitCollection
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    // MARK: - Non-adaptive invariant

    func test_color_validHex_isIdenticalInLightAndDark() {
        let tool = InkTool(kind: .pen, colorHex: "#FF3B30")
        let color = ToolMapper.color(for: tool)
        let l = rgba(color, light)
        let d = rgba(color, dark)
        XCTAssertEqual(l.r, d.r, accuracy: 0.001)
        XCTAssertEqual(l.g, d.g, accuracy: 0.001)
        XCTAssertEqual(l.b, d.b, accuracy: 0.001)
        XCTAssertEqual(l.a, d.a, accuracy: 0.001)
    }

    func test_color_fallback_isIdenticalInLightAndDark() {
        // An unparseable hex forces the fallback path.
        let tool = InkTool(kind: .pen, colorHex: "not-a-color")
        let color = ToolMapper.color(for: tool)
        let l = rgba(color, light)
        let d = rgba(color, dark)
        XCTAssertEqual(l.r, d.r, accuracy: 0.001, "Fallback ink must not adapt to dark mode.")
        XCTAssertEqual(l.g, d.g, accuracy: 0.001)
        XCTAssertEqual(l.b, d.b, accuracy: 0.001)
    }

    // MARK: - Fallback is a visible dark ink, not `.label`

    func test_color_fallback_isDarkAndVisibleOnLightPaper() {
        let tool = InkTool(kind: .pen, colorHex: "")
        let (r, g, b, a) = rgba(ToolMapper.color(for: tool), light)
        // Perceived luminance well below mid-gray so it reads on white paper.
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        XCTAssertLessThan(luminance, 0.3, "Fallback ink should be dark enough to see on light paper.")
        XCTAssertEqual(a, 1, accuracy: 0.001, "Opaque ink fallback expected.")
    }

    func test_color_fallback_doesNotMatchAdaptiveLabel() {
        // `.label` is white in dark mode; the fallback must not behave like it.
        let fallback = ToolMapper.color(for: InkTool(kind: .pen, colorHex: "#ZZZZZZ"))
        let fallbackDark = rgba(fallback, dark)
        let labelDark = rgba(.label, dark)
        let labelLuminance = 0.299 * labelDark.r + 0.587 * labelDark.g + 0.114 * labelDark.b
        let fallbackLuminance = 0.299 * fallbackDark.r + 0.587 * fallbackDark.g + 0.114 * fallbackDark.b
        XCTAssertGreaterThan(labelLuminance, 0.7, "Sanity: .label is light in dark mode.")
        XCTAssertLessThan(fallbackLuminance, 0.3, "Fallback ink stays dark in dark mode, unlike .label.")
    }

    // MARK: - Valid hex parsing

    func test_color_validHex_parsesToExpectedRGB() {
        let (r, g, b, a) = rgba(ToolMapper.color(for: InkTool(kind: .pen, colorHex: "#FF0000")), light)
        XCTAssertEqual(r, 1, accuracy: 0.01)
        XCTAssertEqual(g, 0, accuracy: 0.01)
        XCTAssertEqual(b, 0, accuracy: 0.01)
        XCTAssertEqual(a, 1, accuracy: 0.01)
    }

    // MARK: - Highlighter transparency

    func test_color_highlighter_appliesAlpha() {
        let tool = InkTool(kind: .highlighter, colorHex: "#FFD60A")
        let (_, _, _, a) = rgba(ToolMapper.color(for: tool), light)
        XCTAssertEqual(a, ToolMapper.highlighterAlpha, accuracy: 0.001)
    }

    func test_color_highlighter_appliesAlphaEvenOnFallback() {
        let tool = InkTool(kind: .highlighter, colorHex: "bogus")
        let (_, _, _, a) = rgba(ToolMapper.color(for: tool), light)
        XCTAssertEqual(a, ToolMapper.highlighterAlpha, accuracy: 0.001)
    }

    func test_color_nonHighlighter_isOpaque() {
        for kind in [InkToolKind.pen, .pencil, .marker] {
            let (_, _, _, a) = rgba(ToolMapper.color(for: InkTool(kind: kind, colorHex: "#007AFF")), light)
            XCTAssertEqual(a, 1, accuracy: 0.001, "\(kind) ink should be fully opaque.")
        }
    }
}
