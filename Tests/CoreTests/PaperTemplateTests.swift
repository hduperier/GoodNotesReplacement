import XCTest
import CoreGraphics
@testable import GoodNotesReplacement

final class PaperTemplateTests: XCTestCase {

    // MARK: - PaperSize point sizes (portrait, 72ppi)

    func test_paperSize_portraitPointSizes() {
        XCTAssertEqual(PaperSize.a4.pointSize, CGSize(width: 595, height: 842))
        XCTAssertEqual(PaperSize.a5.pointSize, CGSize(width: 420, height: 595))
        XCTAssertEqual(PaperSize.usLetter.pointSize, CGSize(width: 612, height: 792))
        XCTAssertEqual(PaperSize.square.pointSize, CGSize(width: 600, height: 600))
    }

    func test_paperSize_portraitIsTallerThanWide_exceptSquare() {
        for size in PaperSize.allCases {
            let s = size.pointSize
            if size == .square {
                XCTAssertEqual(s.width, s.height)
            } else {
                XCTAssertGreaterThan(s.height, s.width, "\(size) portrait should be taller than wide.")
            }
        }
    }

    // MARK: - canvasSize orientation

    func test_canvasSize_portrait_matchesPointSize() {
        for size in PaperSize.allCases {
            let template = PaperTemplate(name: "P", style: .blank, size: size, orientation: .portrait)
            XCTAssertEqual(template.canvasSize, size.pointSize,
                           "Portrait canvasSize should equal the raw point size for \(size).")
        }
    }

    func test_canvasSize_landscape_swapsWidthAndHeight() {
        for size in PaperSize.allCases {
            let template = PaperTemplate(name: "L", style: .blank, size: size, orientation: .landscape)
            let p = size.pointSize
            XCTAssertEqual(template.canvasSize, CGSize(width: p.height, height: p.width),
                           "Landscape canvasSize should swap dimensions for \(size).")
        }
    }

    func test_canvasSize_landscape_isWiderThanTall_exceptSquare() {
        for size in PaperSize.allCases where size != .square {
            let template = PaperTemplate(name: "L", style: .lined, size: size, orientation: .landscape)
            XCTAssertGreaterThan(template.canvasSize.width, template.canvasSize.height)
        }
    }

    func test_canvasSize_square_identicalAcrossOrientations() {
        let portrait = PaperTemplate(name: "S", style: .grid, size: .square, orientation: .portrait)
        let landscape = PaperTemplate(name: "S", style: .grid, size: .square, orientation: .landscape)
        XCTAssertEqual(portrait.canvasSize, landscape.canvasSize)
    }

    // MARK: - Built-ins

    func test_builtIns_haveExpectedStyles() {
        XCTAssertEqual(PaperTemplate.builtIns.count, 4)
        XCTAssertEqual(PaperTemplate.builtIns.map(\.style), [.blank, .lined, .grid, .dotted])
    }

    func test_builtIns_defaultToA4Portrait() {
        for template in PaperTemplate.builtIns {
            XCTAssertEqual(template.size, .a4)
            XCTAssertEqual(template.orientation, .portrait)
        }
    }

    func test_namedBuiltIns_haveMatchingStyles() {
        XCTAssertEqual(PaperTemplate.blankWhite.style, .blank)
        XCTAssertEqual(PaperTemplate.lined.style, .lined)
        XCTAssertEqual(PaperTemplate.grid.style, .grid)
        XCTAssertEqual(PaperTemplate.dotted.style, .dotted)
    }

    func test_builtIns_haveUniqueIDs() {
        let ids = PaperTemplate.builtIns.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Built-in templates should have distinct IDs.")
    }

    // MARK: - Codable round-trips

    func test_paperTemplate_codableRoundTrip() throws {
        let original = PaperTemplate(
            name: "Custom Cornell",
            style: .cornell,
            size: .usLetter,
            orientation: .landscape,
            backgroundColorHex: "#FAFAFA",
            lineColorHex: "#C0C0C0",
            lineSpacing: 32
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaperTemplate.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.canvasSize, original.canvasSize)
    }

    func test_paperStyle_codableRoundTrip_allCases() throws {
        for style in PaperStyle.allCases {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(PaperStyle.self, from: data)
            XCTAssertEqual(decoded, style)
        }
    }

    func test_paperSize_codableRoundTrip_allCases() throws {
        for size in PaperSize.allCases {
            let data = try JSONEncoder().encode(size)
            let decoded = try JSONDecoder().decode(PaperSize.self, from: data)
            XCTAssertEqual(decoded, size)
        }
    }

    func test_paperOrientation_codableRoundTrip_allCases() throws {
        for orientation in PaperOrientation.allCases {
            let data = try JSONEncoder().encode(orientation)
            let decoded = try JSONDecoder().decode(PaperOrientation.self, from: data)
            XCTAssertEqual(decoded, orientation)
        }
    }

    func test_paperStyle_rawValuesStable() {
        // Raw values are persisted in SwiftData; guard against accidental renames.
        XCTAssertEqual(PaperStyle.blank.rawValue, "blank")
        XCTAssertEqual(PaperStyle.lined.rawValue, "lined")
        XCTAssertEqual(PaperStyle.grid.rawValue, "grid")
        XCTAssertEqual(PaperStyle.dotted.rawValue, "dotted")
        XCTAssertEqual(PaperStyle.cornell.rawValue, "cornell")
        XCTAssertEqual(PaperStyle.isometric.rawValue, "isometric")
    }

    func test_paperSize_rawValuesStable() {
        XCTAssertEqual(PaperSize.a4.rawValue, "a4")
        XCTAssertEqual(PaperSize.a5.rawValue, "a5")
        XCTAssertEqual(PaperSize.usLetter.rawValue, "usLetter")
        XCTAssertEqual(PaperSize.square.rawValue, "square")
    }

    func test_displayNames_nonEmpty() {
        for style in PaperStyle.allCases {
            XCTAssertFalse(style.displayName.isEmpty)
        }
    }
}
