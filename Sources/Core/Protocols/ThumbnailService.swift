import Foundation
import CoreGraphics

/// Renders page thumbnails (paper background composited with the ink drawing).
/// Implemented in the Canvas layer because it needs PencilKit to rasterize a
/// `PKDrawing`; consumed by the Persistence layer to cache `Page.thumbnailData`.
@MainActor
public protocol ThumbnailService: Sendable {
    /// Renders a PNG thumbnail for the given drawing over its paper template.
    /// - Parameters:
    ///   - drawingData: `PKDrawing.dataRepresentation()`, or nil for a blank page.
    ///   - template: paper background to draw beneath the ink.
    ///   - pointSize: target size in points (scaled by `scale`).
    ///   - scale: pixel scale (e.g. 2.0). Defaults to a thumbnail-appropriate value.
    /// - Returns: PNG data.
    func renderThumbnail(
        drawingData: Data?,
        template: PaperTemplate,
        pointSize: CGSize,
        scale: CGFloat
    ) throws -> Data
}

public extension ThumbnailService {
    /// Convenience: standard library-shelf thumbnail size.
    func renderShelfThumbnail(drawingData: Data?, template: PaperTemplate) throws -> Data {
        try renderThumbnail(
            drawingData: drawingData,
            template: template,
            pointSize: CGSize(width: 220, height: 300),
            scale: 2.0
        )
    }
}
