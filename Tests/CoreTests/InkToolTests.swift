import XCTest
@testable import GoodNotesReplacement

final class InkToolTests: XCTestCase {

    // MARK: - InkToolKind

    func test_inkToolKind_isInking_classification() {
        XCTAssertTrue(InkToolKind.pen.isInking)
        XCTAssertTrue(InkToolKind.pencil.isInking)
        XCTAssertTrue(InkToolKind.marker.isInking)
        XCTAssertTrue(InkToolKind.highlighter.isInking)
        XCTAssertFalse(InkToolKind.eraser.isInking)
        XCTAssertFalse(InkToolKind.lasso.isInking)
    }

    func test_inkToolKind_displayNames_nonEmptyAndUnique() {
        let names = InkToolKind.allCases.map(\.displayName)
        XCTAssertFalse(names.contains(where: \.isEmpty))
        XCTAssertEqual(Set(names).count, names.count)
    }

    func test_inkToolKind_rawValuesStable() {
        XCTAssertEqual(InkToolKind.pen.rawValue, "pen")
        XCTAssertEqual(InkToolKind.pencil.rawValue, "pencil")
        XCTAssertEqual(InkToolKind.marker.rawValue, "marker")
        XCTAssertEqual(InkToolKind.highlighter.rawValue, "highlighter")
        XCTAssertEqual(InkToolKind.eraser.rawValue, "eraser")
        XCTAssertEqual(InkToolKind.lasso.rawValue, "lasso")
    }

    func test_eraserKind_rawValuesStable() {
        XCTAssertEqual(EraserKind.bitmap.rawValue, "bitmap")
        XCTAssertEqual(EraserKind.vector.rawValue, "vector")
    }

    // MARK: - InkTool defaults

    func test_inkTool_defaultInitValues() {
        let tool = InkTool(kind: .pen)
        XCTAssertEqual(tool.kind, .pen)
        XCTAssertEqual(tool.colorHex, "#1C1C1E")
        XCTAssertEqual(tool.width, 3)
        XCTAssertEqual(tool.eraserKind, .vector)
    }

    func test_defaultPen() {
        XCTAssertEqual(InkTool.defaultPen.kind, .pen)
        XCTAssertEqual(InkTool.defaultPen.colorHex, "#1C1C1E")
        XCTAssertEqual(InkTool.defaultPen.width, 3)
    }

    func test_defaultHighlighter() {
        XCTAssertEqual(InkTool.defaultHighlighter.kind, .highlighter)
        XCTAssertEqual(InkTool.defaultHighlighter.colorHex, "#FFD60A")
        XCTAssertEqual(InkTool.defaultHighlighter.width, 18)
    }

    func test_defaultEraser() {
        XCTAssertEqual(InkTool.defaultEraser.kind, .eraser)
        XCTAssertEqual(InkTool.defaultEraser.eraserKind, .vector)
    }

    // MARK: - Codable round-trips

    func test_inkTool_codableRoundTrip() throws {
        let original = InkTool(kind: .marker, colorHex: "#FF9500", width: 7.5, eraserKind: .bitmap)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InkTool.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_inkTool_presets_codableRoundTrip() throws {
        for tool in [InkTool.defaultPen, .defaultHighlighter, .defaultEraser] {
            let data = try JSONEncoder().encode(tool)
            let decoded = try JSONDecoder().decode(InkTool.self, from: data)
            XCTAssertEqual(decoded, tool)
        }
    }

    func test_inkTool_isHashable() {
        let a = InkTool(kind: .pen, colorHex: "#000000", width: 2)
        let b = InkTool(kind: .pen, colorHex: "#000000", width: 2)
        let c = InkTool(kind: .pen, colorHex: "#000000", width: 4)
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set([a, b]).count, 1)
        XCTAssertNotEqual(a, c)
    }

    func test_inkToolKind_codableRoundTrip_allCases() throws {
        for kind in InkToolKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(InkToolKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    // MARK: - ColorSwatches

    func test_colorSwatches_starter_contents() {
        XCTAssertEqual(ColorSwatches.starter.count, 8)
        XCTAssertEqual(ColorSwatches.starter.first, "#1C1C1E")
        XCTAssertEqual(ColorSwatches.starter.last, "#FFFFFF")
    }

    func test_colorSwatches_starter_allHexFormatted() {
        for hex in ColorSwatches.starter {
            XCTAssertTrue(hex.hasPrefix("#"), "Swatch \(hex) should start with #.")
            XCTAssertEqual(hex.count, 7, "Swatch \(hex) should be #RRGGBB.")
        }
    }

    func test_colorSwatches_defaultInit_usesStarter() {
        XCTAssertEqual(ColorSwatches().hexValues, ColorSwatches.starter)
    }

    func test_colorSwatches_codableRoundTrip() throws {
        let original = ColorSwatches(hexValues: ["#000000", "#FFFFFF", "#FF0000"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ColorSwatches.self, from: data)
        XCTAssertEqual(decoded.hexValues, original.hexValues)
    }
}
