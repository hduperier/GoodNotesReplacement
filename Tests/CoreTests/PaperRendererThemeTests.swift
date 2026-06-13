import XCTest
import UIKit
import CoreGraphics
@testable import GoodNotesReplacement

/// Theming contract for the paper background.
///
/// Policy: the page is document content, not chrome — it stays light regardless
/// of the system appearance. `PaperRenderer` draws from fixed hex colors, so a
/// render produced while the current trait is `.dark` must be pixel-identical to
/// one produced in `.light`, and the background must remain light in both.
@MainActor
final class PaperRendererThemeTests: XCTestCase {

    private let light = UITraitCollection(userInterfaceStyle: .light)
    private let dark = UITraitCollection(userInterfaceStyle: .dark)

    // MARK: - Pixel helpers

    private struct Bitmap { let px: [UInt8]; let w: Int; let h: Int }

    /// Decodes `image` into a tightly-packed RGBA8 buffer for pixel inspection.
    private func bitmap(_ image: UIImage) -> Bitmap {
        guard let cg = image.cgImage else { return Bitmap(px: [], w: 0, h: 0) }
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        px.withUnsafeMutableBytes { raw in
            let ctx = CGContext(
                data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: w * 4, space: space, bitmapInfo: info
            )
            ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return Bitmap(px: px, w: w, h: h)
    }

    private func pixel(_ b: Bitmap, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
        let i = (y * b.w + x) * 4
        return (Int(b.px[i]), Int(b.px[i + 1]), Int(b.px[i + 2]), Int(b.px[i + 3]))
    }

    private func assertLight(_ p: (r: Int, g: Int, b: Int, a: Int), _ message: String) {
        XCTAssertGreaterThan(p.r, 240, message)
        XCTAssertGreaterThan(p.g, 240, message)
        XCTAssertGreaterThan(p.b, 240, message)
    }

    // MARK: - Background stays light

    func test_blankPaper_backgroundIsLight() {
        let b = bitmap(PaperRenderer.image(for: .blankWhite, scale: 1))
        XCTAssertGreaterThan(b.w, 0, "Renderer produced an empty image.")
        assertLight(pixel(b, 2, 2), "Blank paper should render a light background.")
    }

    func test_paper_staysLight_whenCurrentTraitIsDark() {
        var image: UIImage!
        dark.performAsCurrent { image = PaperRenderer.image(for: .lined, scale: 1) }
        let b = bitmap(image)
        // Sample near the top-left, before the first rule line (spacing = 28pt).
        assertLight(pixel(b, 2, 2), "Paper background must stay light under a dark trait.")
    }

    // MARK: - Render is appearance-independent

    func test_paper_render_isPixelIdenticalAcrossAppearances() {
        var lightImage: UIImage!
        var darkImage: UIImage!
        light.performAsCurrent { lightImage = PaperRenderer.image(for: .grid, scale: 1) }
        dark.performAsCurrent { darkImage = PaperRenderer.image(for: .grid, scale: 1) }

        let lb = bitmap(lightImage)
        let db = bitmap(darkImage)
        XCTAssertEqual(lb.w, db.w)
        XCTAssertEqual(lb.h, db.h)
        XCTAssertEqual(lb.px, db.px, "Paper must render identically regardless of system appearance.")
    }

    // MARK: - Renderer color fallbacks are light/neutral

    func test_paper_invalidBackgroundHex_fallsBackToWhite() {
        let template = PaperTemplate(
            name: "Bad", style: .blank,
            backgroundColorHex: "not-a-color", lineColorHex: "not-a-color"
        )
        let b = bitmap(PaperRenderer.image(for: template, scale: 1))
        assertLight(pixel(b, 2, 2), "Invalid background hex should fall back to white, not a dark color.")
    }
}
