import Foundation

/// The drawing tools exposed by the toolbar. These map onto PencilKit's
/// `PKInkingTool`/`PKEraserTool`/`PKLassoTool` in the Canvas layer.
public enum InkToolKind: String, Codable, CaseIterable, Sendable {
    case pen        // fixed-width ink
    case pencil     // textured, pressure/tilt sensitive
    case marker     // calligraphic / fountain feel
    case highlighter
    case eraser
    case lasso

    public var displayName: String {
        switch self {
        case .pen: "Pen"
        case .pencil: "Pencil"
        case .marker: "Marker"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .lasso: "Lasso"
        }
    }

    public var isInking: Bool {
        switch self {
        case .pen, .pencil, .marker, .highlighter: true
        case .eraser, .lasso: false
        }
    }
}

/// Granularity of the eraser.
public enum EraserKind: String, Codable, CaseIterable, Sendable {
    case bitmap   // erase pixels
    case vector   // erase whole strokes
}

/// A serializable description of the active tool. The Canvas layer converts
/// this to a concrete `PKTool`; the UI layer binds the toolbar to it.
public struct InkTool: Codable, Hashable, Sendable {
    public var kind: InkToolKind
    public var colorHex: String
    public var width: Double
    public var eraserKind: EraserKind

    public init(
        kind: InkToolKind,
        colorHex: String = "#1C1C1E",
        width: Double = 3,
        eraserKind: EraserKind = .vector
    ) {
        self.kind = kind
        self.colorHex = colorHex
        self.width = width
        self.eraserKind = eraserKind
    }

    public static let defaultPen = InkTool(kind: .pen, colorHex: "#1C1C1E", width: 3)
    public static let defaultHighlighter = InkTool(kind: .highlighter, colorHex: "#FFD60A", width: 18)
    public static let defaultEraser = InkTool(kind: .eraser, eraserKind: .vector)
}

/// A small, user-curated palette of recently/favourited colors shown in the
/// toolbar. Stored in app settings, not the document.
public struct ColorSwatches: Codable, Sendable {
    public var hexValues: [String]
    public init(hexValues: [String] = ColorSwatches.starter) {
        self.hexValues = hexValues
    }
    public static let starter = [
        "#1C1C1E", "#FF3B30", "#FF9500", "#FFCC00",
        "#34C759", "#007AFF", "#5856D6", "#FFFFFF"
    ]
}
