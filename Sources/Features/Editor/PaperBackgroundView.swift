import SwiftUI

/// SwiftUI host for the live paper background, drawn with the same `PaperRenderer`
/// the thumbnails use so live and cached renders match. Sized to the template's
/// canvas size; the parent scales it to fit the available space.
@MainActor
struct PaperBackgroundView: View {
    let template: PaperTemplate

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            context.drawLayer { layer in
                layer.withCGContext { cg in
                    PaperRenderer.draw(template, in: cg, size: size)
                }
            }
        }
    }
}

#Preview {
    PaperBackgroundView(template: .grid)
        .aspectRatio(PaperTemplate.grid.canvasSize.width / PaperTemplate.grid.canvasSize.height,
                     contentMode: .fit)
        .padding()
}
