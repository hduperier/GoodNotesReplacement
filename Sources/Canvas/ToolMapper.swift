import Foundation
import PencilKit
import UIKit

/// Converts the serializable `InkTool` value type into a concrete PencilKit
/// tool (`PKInkingTool` / `PKEraserTool` / `PKLassoTool`).
///
/// Mapping summary:
/// - `pen`         → `PKInkingTool(.pen, …)`     (fixed-width ink)
/// - `pencil`      → `PKInkingTool(.pencil, …)`  (textured, tilt sensitive)
/// - `marker`      → `PKInkingTool(.marker, …)`  (calligraphic)
/// - `highlighter` → `PKInkingTool(.marker, …)`  with a translucent color and a
///                   wide default width (PencilKit has no dedicated highlighter
///                   ink type pre-26; marker + alpha reproduces the feel)
/// - `eraser`      → `PKEraserTool(.vector)` or `.bitmap`
/// - `lasso`       → `PKLassoTool()`
public enum ToolMapper {

    /// Alpha applied to a highlighter stroke so underlying ink shows through.
    public static let highlighterAlpha: CGFloat = 0.4

    /// Builds the PencilKit tool for the given `InkTool`.
    @MainActor
    public static func pkTool(for tool: InkTool) -> PKTool {
        switch tool.kind {
        case .pen:
            return PKInkingTool(.pen, color: color(for: tool), width: width(for: tool))
        case .pencil:
            return PKInkingTool(.pencil, color: color(for: tool), width: width(for: tool))
        case .marker:
            return PKInkingTool(.marker, color: color(for: tool), width: width(for: tool))
        case .highlighter:
            // Marker ink with a translucent color reproduces a highlighter.
            return PKInkingTool(.marker, color: color(for: tool), width: width(for: tool))
        case .eraser:
            switch tool.eraserKind {
            case .vector: return PKEraserTool(.vector)
            case .bitmap: return PKEraserTool(.bitmap)
            }
        case .lasso:
            return PKLassoTool()
        }
    }

    /// Resolved stroke color, applying highlighter transparency where relevant.
    @MainActor
    public static func color(for tool: InkTool) -> UIColor {
        // Fall back to a fixed near-black rather than `.label`: ink is drawn on
        // the (light) paper, so a dark-mode-adaptive `.label` would resolve to
        // white and render invisible. Paper color is document content and does
        // not follow the system appearance.
        let base = UIColor(hex: tool.colorHex) ?? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        if tool.kind == .highlighter {
            return base.withAlphaComponent(highlighterAlpha)
        }
        return base
    }

    /// Resolved stroke width, clamped to PencilKit's valid range for the ink.
    public static func width(for tool: InkTool) -> CGFloat {
        CGFloat(max(1, tool.width))
    }
}

public extension UIColor {
    /// Parses `#RRGGBB` or `#RRGGBBAA` (the leading `#` is optional). Returns nil
    /// when the string is not a valid 6- or 8-digit hex color.
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8,
              let value = UInt64(s, radix: 16) else {
            return nil
        }

        let r, g, b, a: CGFloat
        if s.count == 6 {
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
            a = 1
        } else {
            r = CGFloat((value & 0xFF000000) >> 24) / 255
            g = CGFloat((value & 0x00FF0000) >> 16) / 255
            b = CGFloat((value & 0x0000FF00) >> 8) / 255
            a = CGFloat(value & 0x000000FF) / 255
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }

    /// Serializes back to `#RRGGBB` (or `#RRGGBBAA` when not fully opaque).
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        // Convert through the extended/sRGB space so colors created from
        // `UIColor(red:green:blue:)` and from system colors both resolve.
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return "#000000" }
        let ri = Int((r * 255).rounded())
        let gi = Int((g * 255).rounded())
        let bi = Int((b * 255).rounded())
        if a >= 0.999 {
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        }
        let ai = Int((a * 255).rounded())
        return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
    }
}
