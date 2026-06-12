import Foundation

/// Visual style of a page's background. Mirrors GoodNotes' core paper set
/// (minus their proprietary designer templates).
public enum PaperStyle: String, Codable, CaseIterable, Sendable {
    case blank
    case lined
    case grid
    case dotted
    case cornell
    case isometric

    public var displayName: String {
        switch self {
        case .blank: "Blank"
        case .lined: "Lined"
        case .grid: "Grid"
        case .dotted: "Dotted"
        case .cornell: "Cornell"
        case .isometric: "Isometric"
        }
    }
}

/// Physical page proportions. Drawing coordinates are template-relative so a
/// page renders identically regardless of device.
public enum PaperSize: String, Codable, CaseIterable, Sendable {
    case a4
    case a5
    case usLetter
    case square

    /// Page dimensions in points (portrait), 72ppi.
    public var pointSize: CGSize {
        switch self {
        case .a4: CGSize(width: 595, height: 842)
        case .a5: CGSize(width: 420, height: 595)
        case .usLetter: CGSize(width: 612, height: 792)
        case .square: CGSize(width: 600, height: 600)
        }
    }
}

public enum PaperOrientation: String, Codable, CaseIterable, Sendable {
    case portrait
    case landscape
}

/// A fully-resolved description of a page background. Stored on each `Page`
/// so a notebook can mix templates. `PaperRenderer` (Canvas layer) draws it.
public struct PaperTemplate: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var style: PaperStyle
    public var size: PaperSize
    public var orientation: PaperOrientation
    /// Page (background) color as #RRGGBB or #RRGGBBAA.
    public var backgroundColorHex: String
    /// Rule/grid/dot color.
    public var lineColorHex: String
    /// Spacing between rules, grid lines, or dots, in points.
    public var lineSpacing: Double

    public init(
        id: UUID = UUID(),
        name: String,
        style: PaperStyle,
        size: PaperSize = .a4,
        orientation: PaperOrientation = .portrait,
        backgroundColorHex: String = "#FFFFFF",
        lineColorHex: String = "#D7D7DC",
        lineSpacing: Double = 28
    ) {
        self.id = id
        self.name = name
        self.style = style
        self.size = size
        self.orientation = orientation
        self.backgroundColorHex = backgroundColorHex
        self.lineColorHex = lineColorHex
        self.lineSpacing = lineSpacing
    }

    /// Resolved canvas size taking orientation into account.
    public var canvasSize: CGSize {
        let s = size.pointSize
        return orientation == .portrait ? s : CGSize(width: s.height, height: s.width)
    }
}

public extension PaperTemplate {
    static let blankWhite = PaperTemplate(name: "Blank", style: .blank)
    static let lined = PaperTemplate(name: "Lined", style: .lined)
    static let grid = PaperTemplate(name: "Grid", style: .grid)
    static let dotted = PaperTemplate(name: "Dotted", style: .dotted)

    /// Templates offered in the "new page / new notebook" picker.
    static let builtIns: [PaperTemplate] = [.blankWhite, .lined, .grid, .dotted]
}
