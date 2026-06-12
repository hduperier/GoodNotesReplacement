import SwiftUI

/// The notebook editor: a paged canvas over a rendered paper background, with a
/// drawing toolbar and a page thumbnail strip. Drawing edits flow (debounced)
/// into `DocumentStore.updateDrawing`.
@MainActor
struct NotebookEditorView: View {
    @Bindable var notebook: Notebook

    @Environment(\.documentStore) private var store

    @State private var currentIndex = 0
    @State private var tool: InkTool = .defaultPen
    @StateObject private var undo = UndoController()

    /// Bumped after page-structure mutations so the view re-reads the store.
    @State private var refreshToken = 0
    @State private var showStrip = true

    private var swatches: [String] { ColorSwatches.starter }

    private var pages: [Page] { notebook.orderedPages }

    private var currentPage: Page? {
        let p = pages
        guard p.indices.contains(currentIndex) else { return p.last }
        return p[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            let _ = refreshToken

            ToolbarView(
                tool: $tool,
                swatches: swatches,
                undo: undo,
                onUndo: { undo.undo() },
                onRedo: { undo.redo() }
            )

            Divider()

            canvasArea
                .background(Color(.systemGroupedBackground))

            if showStrip {
                Divider()
                PageThumbnailStrip(
                    pages: pages,
                    currentIndex: $currentIndex,
                    onSelect: { goTo($0) },
                    onAddPage: { addPage() },
                    onDuplicate: { duplicate($0) },
                    onDelete: { delete($0) },
                    onMove: { from, to in movePage(from: from, to: to) }
                )
                .frame(height: 116)
            }
        }
        .navigationTitle(notebook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Text(pageLabel)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("editor.pageLabel")

                Button {
                    withAnimation { showStrip.toggle() }
                } label: {
                    Image(systemName: showStrip ? "rectangle.bottomthird.inset.filled" : "rectangle")
                }
                .accessibilityIdentifier("editor.toggleStrip")
            }
        }
        .onAppear { clampIndex() }
    }

    // MARK: - Canvas

    @ViewBuilder
    private var canvasArea: some View {
        if let page = currentPage {
            GeometryReader { geo in
                let canvasSize = page.template.canvasSize
                let scale = fitScale(for: canvasSize, in: geo.size)
                ZStack {
                    // Page rendered at its NATIVE template size so PencilKit ink
                    // is stored template-relative (matching the thumbnails), then
                    // scaled to fit the available area.
                    ZStack {
                        PaperBackgroundView(template: page.template)
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .shadow(color: .black.opacity(0.15), radius: 6 / scale, x: 0, y: 3 / scale)

                        PencilKitCanvasView(
                            pageID: page.id,
                            drawingData: page.drawingData,
                            template: page.template,
                            tool: tool,
                            undoController: undo,
                            onDrawingChanged: { data in
                                saveDrawing(data, for: page)
                            }
                        )
                        .frame(width: canvasSize.width, height: canvasSize.height)
                    }
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height)

                    // Explicit prev/next overlays in the side margins. Kept off
                    // the page itself so they never intercept Pencil strokes.
                    HStack {
                        pageNavButton(systemImage: "chevron.left", id: "editor.prevPage") {
                            goTo(currentIndex - 1)
                        }
                        .opacity(currentIndex > 0 ? 1 : 0)
                        Spacer()
                        pageNavButton(systemImage: "chevron.right", id: "editor.nextPage") {
                            goTo(currentIndex + 1)
                        }
                        .opacity(currentIndex < pages.count - 1 ? 1 : 0)
                    }
                    .padding(.horizontal, 4)
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .padding(20)
        } else {
            ContentUnavailableView("No Pages", systemImage: "doc")
        }
    }

    private func pageNavButton(systemImage: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 56)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// Uniform scale that aspect-fits a `content`-sized page into `bounds`.
    private func fitScale(for content: CGSize, in bounds: CGSize) -> CGFloat {
        guard content.width > 0, content.height > 0,
              bounds.width > 0, bounds.height > 0 else { return 1 }
        return min(bounds.width / content.width, bounds.height / content.height)
    }

    private var pageLabel: String {
        guard !pages.isEmpty else { return "0 / 0" }
        return "\(min(currentIndex + 1, pages.count)) / \(pages.count)"
    }

    // MARK: - Navigation

    private func goTo(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { currentIndex = index }
    }

    private func clampIndex() {
        if pages.isEmpty { currentIndex = 0 }
        else { currentIndex = min(currentIndex, pages.count - 1) }
    }

    // MARK: - Mutations

    private func saveDrawing(_ data: Data, for page: Page) {
        try? store.updateDrawing(for: page, drawingData: data)
        try? store.save()
        // No structural refresh needed; thumbnail refresh happens in the store.
    }

    private func addPage() {
        let anchor = currentPage
        if let new = try? store.addPage(to: notebook, after: anchor, template: notebook.defaultTemplate) {
            try? store.save()
            bump()
            goTo(new.index)
        }
    }

    private func duplicate(_ page: Page) {
        if let copy = try? store.duplicatePage(page) {
            try? store.save()
            bump()
            goTo(copy.index)
        }
    }

    private func delete(_ page: Page) {
        guard pages.count > 1 else { return }
        let removedIndex = page.index
        try? store.deletePage(page)
        try? store.save()
        bump()
        clampIndex()
        if currentIndex >= removedIndex { currentIndex = max(0, min(currentIndex, pages.count - 1)) }
    }

    private func movePage(from: Int, to: Int) {
        guard pages.indices.contains(from) else { return }
        let page = pages[from]
        try? store.movePage(page, to: to)
        try? store.save()
        bump()
        currentIndex = max(0, min(to, pages.count - 1))
    }

    private func bump() { refreshToken &+= 1 }
}

#Preview("Editor") {
    let store = InMemoryDocumentStore(seed: true)
    let nb = store.rootNotebooks.first ?? (try! store.createNotebook(title: "Demo", in: nil, template: .lined))
    return NavigationStack {
        NotebookEditorView(notebook: nb)
    }
    .documentStore(store)
}
