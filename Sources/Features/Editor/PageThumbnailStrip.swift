import SwiftUI

/// Horizontal strip of page thumbnails along the editor edge. Tapping a
/// thumbnail jumps to that page; a context menu offers duplicate/delete, and an
/// "add page" tile sits at the end.
@MainActor
struct PageThumbnailStrip: View {
    let pages: [Page]
    @Binding var currentIndex: Int
    let onSelect: (Int) -> Void
    let onAddPage: () -> Void
    let onDuplicate: (Page) -> Void
    let onDelete: (Page) -> Void
    let onMove: (_ from: Int, _ to: Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { offset, page in
                        thumbnail(page: page, offset: offset)
                            .id(offset)
                    }
                    addTile
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: currentIndex) { _, idx in
                withAnimation { proxy.scrollTo(idx, anchor: .center) }
            }
        }
        .background(.bar)
    }

    private func thumbnail(page: Page, offset: Int) -> some View {
        VStack(spacing: 4) {
            PageThumbnailView(
                drawingData: page.drawingData,
                thumbnailData: page.thumbnailData,
                template: page.template
            )
            .frame(width: 60, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(offset == currentIndex ? Color.accentColor : Color(.separator),
                                  lineWidth: offset == currentIndex ? 2.5 : 0.5)
            )
            Text("\(offset + 1)")
                .font(.caption2)
                .foregroundStyle(offset == currentIndex ? Color.accentColor : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(offset) }
        .accessibilityIdentifier("editor.pageThumb.\(offset)")
        .contextMenu {
            Button { onDuplicate(page) } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            if offset > 0 {
                Button { onMove(offset, offset - 1) } label: {
                    Label("Move Left", systemImage: "arrow.left")
                }
            }
            if offset < pages.count - 1 {
                Button { onMove(offset, offset + 1) } label: {
                    Label("Move Right", systemImage: "arrow.right")
                }
            }
            Divider()
            Button(role: .destructive) { onDelete(page) } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(pages.count <= 1)
        }
    }

    private var addTile: some View {
        Button(action: onAddPage) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(width: 60, height: 80)
                    .overlay(Image(systemName: "plus").font(.title3).foregroundStyle(.secondary))
                Text("Add").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editor.addPage")
    }
}
