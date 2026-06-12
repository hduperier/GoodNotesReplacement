import SwiftUI
import UIKit

/// Renders a single page preview. Prefers the page's cached `thumbnailData`;
/// when absent (e.g. a freshly created page in the in-memory store) it renders
/// the paper background live via `PaperRenderer` and composites the ink on
/// demand through the injected `ThumbnailService`.
@MainActor
struct PageThumbnailView: View {
    let drawingData: Data?
    let thumbnailData: Data?
    let template: PaperTemplate

    @Environment(\.thumbnailService) private var thumbnailService

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .aspectRatio(aspect, contentMode: .fit)
    }

    private var aspect: CGFloat {
        let s = template.canvasSize
        return s.height > 0 ? s.width / s.height : 0.75
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if let thumbnailData, let ui = UIImage(data: thumbnailData) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let ui = liveRender(size: size) {
            Image(uiImage: ui)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color(hex: template.backgroundColorHex)
        }
    }

    private func liveRender(size: CGSize) -> UIImage? {
        // Render at a sane minimum size to keep the work bounded.
        let point = CGSize(width: max(80, size.width), height: max(120, size.height))
        guard let data = try? thumbnailService.renderThumbnail(
            drawingData: drawingData,
            template: template,
            pointSize: point,
            scale: 2.0
        ) else { return nil }
        return UIImage(data: data)
    }
}
