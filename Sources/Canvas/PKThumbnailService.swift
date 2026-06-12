import Foundation
import CoreGraphics
import PencilKit
import UIKit

/// `ThumbnailService` implementation that composites a `PaperRenderer` paper
/// background with a rasterized `PKDrawing` into PNG data. Used by the
/// Persistence layer to cache `Page.thumbnailData`, and by the UI to render
/// off-screen pages from their cached thumbnail.
public final class PKThumbnailService: ThumbnailService {

    public init() {}

    public func renderThumbnail(
        drawingData: Data?,
        template: PaperTemplate,
        pointSize: CGSize,
        scale: CGFloat
    ) throws -> Data {
        let canvas = template.canvasSize
        guard canvas.width > 0, canvas.height > 0,
              pointSize.width > 0, pointSize.height > 0 else {
            throw DocumentStoreError.invalidIndex
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale > 0 ? scale : 2.0
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext

            // Aspect-fit the page into the thumbnail, centered, letterboxed with
            // the page background color so proportions are preserved.
            let fitted = Self.aspectFitRect(content: canvas, into: pointSize)

            // Fill the whole thumbnail with the page background first (so the
            // letterbox bars match the paper rather than showing black).
            let bg = UIColor(hex: template.backgroundColorHex) ?? .white
            cg.setFillColor(bg.cgColor)
            cg.fill(CGRect(origin: .zero, size: pointSize))

            // Map template-space into the fitted rect.
            cg.saveGState()
            cg.translateBy(x: fitted.minX, y: fitted.minY)
            cg.scaleBy(x: fitted.width / canvas.width, y: fitted.height / canvas.height)

            // 1. Paper background in template space.
            PaperRenderer.draw(template, in: cg, size: canvas)
            cg.restoreGState()

            // 2. Ink on top, scaled to the fitted rect.
            if let data = drawingData, !data.isEmpty,
               let drawing = try? PKDrawing(data: data) {
                let inkImage = drawing.image(from: CGRect(origin: .zero, size: canvas), scale: format.scale)
                inkImage.draw(in: fitted)
            }
        }

        guard let png = image.pngData() else {
            throw DocumentStoreError.persistenceFailure("Failed to encode thumbnail PNG")
        }
        return png
    }

    /// Centered aspect-fit of `content` inside `bounds`.
    static func aspectFitRect(content: CGSize, into bounds: CGSize) -> CGRect {
        guard content.width > 0, content.height > 0 else {
            return CGRect(origin: .zero, size: bounds)
        }
        let scale = min(bounds.width / content.width, bounds.height / content.height)
        let w = content.width * scale
        let h = content.height * scale
        return CGRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
    }
}
