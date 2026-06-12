import SwiftUI

/// A single notebook tile on the shelf: cover color spine, first-page thumbnail,
/// title and page count.
@MainActor
struct NotebookCardView: View {
    let notebook: Notebook

    private var firstPage: Page? { notebook.orderedPages.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .leading) {
                // Cover thumbnail.
                Group {
                    if let page = firstPage {
                        PageThumbnailView(
                            drawingData: page.drawingData,
                            thumbnailData: page.thumbnailData,
                            template: page.template
                        )
                    } else {
                        Color(hex: notebook.coverColorHex)
                            .aspectRatio(0.75, contentMode: .fit)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                )

                // Cover-color spine down the left edge.
                Color(hex: notebook.coverColorHex)
                    .frame(width: 10)
                    .clipShape(
                        .rect(topLeadingRadius: 8, bottomLeadingRadius: 8)
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

            Text(notebook.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text("^[\(notebook.pageCount) page](inflect: true)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(notebook.title), \(notebook.pageCount) pages")
    }
}
