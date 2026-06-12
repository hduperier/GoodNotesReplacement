import Foundation
import CoreGraphics
import UIKit

/// Deterministically draws a `PaperTemplate` background into a `CGContext`.
///
/// The same renderer is used live (beneath the canvas) and for thumbnails so the
/// two always match. All drawing is in template-relative coordinates: the caller
/// is responsible for sizing/scaling the context to `template.canvasSize`.
public enum PaperRenderer {

    /// Draws `template`'s background into `context`, filling the rect
    /// `(0, 0, size.width, size.height)`. `size` defaults to the template's
    /// canvas size; pass a different size only when you have already applied a
    /// scale transform to the context.
    public static func draw(
        _ template: PaperTemplate,
        in context: CGContext,
        size: CGSize? = nil
    ) {
        let canvas = size ?? template.canvasSize
        let rect = CGRect(origin: .zero, size: canvas)

        // 1. Background fill.
        let bg = UIColor(hex: template.backgroundColorHex) ?? .white
        context.setFillColor(bg.cgColor)
        context.fill(rect)

        // 2. Rules / grid / dots.
        let lineColor = UIColor(hex: template.lineColorHex) ?? UIColor(white: 0.84, alpha: 1)
        let spacing = max(4, CGFloat(template.lineSpacing))

        switch template.style {
        case .blank:
            break

        case .lined:
            drawHorizontalLines(in: context, rect: rect, spacing: spacing, color: lineColor)

        case .grid:
            drawHorizontalLines(in: context, rect: rect, spacing: spacing, color: lineColor)
            drawVerticalLines(in: context, rect: rect, spacing: spacing, color: lineColor)

        case .dotted:
            drawDots(in: context, rect: rect, spacing: spacing, color: lineColor)

        case .cornell:
            // Lined body with a left margin column and a bottom summary rule.
            drawHorizontalLines(in: context, rect: rect, spacing: spacing, color: lineColor)
            drawCornellGuides(in: context, rect: rect, color: lineColor)

        case .isometric:
            drawIsometric(in: context, rect: rect, spacing: spacing, color: lineColor)
        }
    }

    // MARK: - Line styles

    private static func drawHorizontalLines(
        in context: CGContext, rect: CGRect, spacing: CGFloat, color: UIColor
    ) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1)
        let path = CGMutablePath()
        var y = spacing
        while y < rect.height {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        context.addPath(path)
        context.strokePath()
    }

    private static func drawVerticalLines(
        in context: CGContext, rect: CGRect, spacing: CGFloat, color: UIColor
    ) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1)
        let path = CGMutablePath()
        var x = spacing
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }
        context.addPath(path)
        context.strokePath()
    }

    private static func drawDots(
        in context: CGContext, rect: CGRect, spacing: CGFloat, color: UIColor
    ) {
        context.setFillColor(color.cgColor)
        let radius: CGFloat = max(0.75, min(1.5, spacing * 0.05))
        var y = spacing
        while y < rect.height {
            var x = spacing
            while x < rect.width {
                let dot = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fillEllipse(in: dot)
                x += spacing
            }
            y += spacing
        }
    }

    private static func drawCornellGuides(
        in context: CGContext, rect: CGRect, color: UIColor
    ) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.5)
        let path = CGMutablePath()
        // Left margin column (~22% of width).
        let marginX = rect.minX + rect.width * 0.22
        path.move(to: CGPoint(x: marginX, y: rect.minY))
        path.addLine(to: CGPoint(x: marginX, y: rect.maxY))
        // Bottom summary rule (~18% from the bottom).
        let summaryY = rect.maxY - rect.height * 0.18
        path.move(to: CGPoint(x: rect.minX, y: summaryY))
        path.addLine(to: CGPoint(x: rect.maxX, y: summaryY))
        context.addPath(path)
        context.strokePath()
    }

    private static func drawIsometric(
        in context: CGContext, rect: CGRect, spacing: CGFloat, color: UIColor
    ) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(0.75)
        // Vertical lines + two diagonal families at ±30° produce a triangular grid.
        drawVerticalLines(in: context, rect: rect, spacing: spacing, color: color)

        let slope = tan(30.0 * .pi / 180.0) // rise over run for a 30° line
        let dx = rect.width
        let dyForSpan = slope * dx
        let path = CGMutablePath()

        // Lines descending to the right (positive slope).
        var c = rect.minY - dyForSpan
        while c < rect.maxY + dyForSpan {
            path.move(to: CGPoint(x: rect.minX, y: c))
            path.addLine(to: CGPoint(x: rect.maxX, y: c + dyForSpan))
            c += spacing
        }
        // Lines ascending to the right (negative slope).
        c = rect.minY - dyForSpan
        while c < rect.maxY + dyForSpan {
            path.move(to: CGPoint(x: rect.minX, y: c + dyForSpan))
            path.addLine(to: CGPoint(x: rect.maxX, y: c))
            c += spacing
        }
        context.addPath(path)
        context.strokePath()
    }

    // MARK: - Image convenience

    /// Renders the template to a `UIImage` at the given scale. Useful for
    /// SwiftUI backgrounds where a layer-backed image is simpler than a custom
    /// `CGContext` draw.
    @MainActor
    public static func image(for template: PaperTemplate, scale: CGFloat = 0) -> UIImage {
        let size = template.canvasSize
        let format = UIGraphicsImageRendererFormat.default()
        if scale > 0 { format.scale = scale }
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            draw(template, in: ctx.cgContext, size: size)
        }
    }
}
