import Foundation
import SwiftData

/// SwiftData-backed implementation of `DocumentStore`.
///
/// Mirrors the ordering, cascade, and duplicate semantics documented in
/// `DocumentStore` and demonstrated by `InMemoryDocumentStore`, but persists
/// through an injected `ModelContext` and refreshes page thumbnails through an
/// injected `ThumbnailService`.
///
/// All access is `@MainActor`: SwiftData `@Model` instances and the injected
/// `ModelContext` (the container's `mainContext`) are main-actor bound.
@MainActor
public final class SwiftDataDocumentStore: DocumentStore {

    private let context: ModelContext
    private let thumbnails: ThumbnailService

    /// - Parameters:
    ///   - context: the container's `mainContext` (or any main-actor context).
    ///   - thumbnails: renders cached page thumbnails after ink changes.
    public init(context: ModelContext, thumbnails: ThumbnailService) {
        self.context = context
        self.thumbnails = thumbnails
    }

    public static var schema: Schema { AppSchema.schema }

    // MARK: - Folders

    @discardableResult
    public func createFolder(name: String, parent: Folder?) throws -> Folder {
        let siblingCount = try parent?.subfolders.count ?? rootFolders().count
        let folder = Folder(name: name, parent: parent, sortIndex: siblingCount)
        context.insert(folder)
        if let parent {
            parent.subfolders.append(folder)
            touch(parent)
        }
        try save()
        return folder
    }

    public func renameFolder(_ folder: Folder, to name: String) throws {
        folder.name = name
        touch(folder)
        try save()
    }

    public func deleteFolder(_ folder: Folder) throws {
        // The model's `.cascade` rules delete subfolders, notebooks, and pages.
        context.delete(folder)
        try save()
    }

    public func moveFolder(_ folder: Folder, into parent: Folder?) throws {
        if folder.id == parent?.id { return }
        folder.parent = parent
        if let parent {
            folder.sortIndex = parent.subfolders.count
        } else {
            folder.sortIndex = try rootFolders().count
        }
        touch(folder)
        try save()
    }

    // MARK: - Notebooks

    @discardableResult
    public func createNotebook(title: String, in folder: Folder?, template: PaperTemplate) throws -> Notebook {
        let count = try folder?.notebooks.count ?? rootNotebooks().count
        let notebook = Notebook(title: title, folder: folder, defaultTemplate: template, sortIndex: count)
        context.insert(notebook)
        // Seed exactly one blank page at index 0 with the chosen template.
        let firstPage = Page(index: 0, template: template, notebook: notebook)
        context.insert(firstPage)
        notebook.pages.append(firstPage)
        if let folder {
            folder.notebooks.append(notebook)
            touch(folder)
        }
        try save()
        return notebook
    }

    public func renameNotebook(_ notebook: Notebook, to title: String) throws {
        notebook.title = title
        touch(notebook)
        try save()
    }

    public func deleteNotebook(_ notebook: Notebook) throws {
        // `.cascade` on `Notebook.pages` removes the pages.
        context.delete(notebook)
        try save()
    }

    public func moveNotebook(_ notebook: Notebook, into folder: Folder?) throws {
        notebook.folder = folder
        if let folder {
            notebook.sortIndex = folder.notebooks.count
        } else {
            notebook.sortIndex = try rootNotebooks().count
        }
        touch(notebook)
        try save()
    }

    @discardableResult
    public func duplicateNotebook(_ notebook: Notebook) throws -> Notebook {
        let copy = Notebook(
            title: notebook.title + " copy",
            folder: notebook.folder,
            defaultTemplate: notebook.defaultTemplate,
            coverColorHex: notebook.coverColorHex,
            sortIndex: notebook.sortIndex + 1
        )
        context.insert(copy)
        // Deep-copy pages (ink + thumbnail) preserving order/index.
        for page in notebook.orderedPages {
            let p = Page(index: page.index, template: page.template, notebook: copy)
            p.drawingData = page.drawingData
            p.thumbnailData = page.thumbnailData
            context.insert(p)
            copy.pages.append(p)
        }
        if let folder = notebook.folder {
            folder.notebooks.append(copy)
            touch(folder)
        }
        try save()
        return copy
    }

    // MARK: - Pages

    @discardableResult
    public func addPage(to notebook: Notebook, after page: Page?, template: PaperTemplate) throws -> Page {
        let insertIndex = (page?.index).map { $0 + 1 } ?? notebook.pages.count
        // Shift following pages up to make room.
        for p in notebook.pages where p.index >= insertIndex { p.index += 1 }
        let newPage = Page(index: insertIndex, template: template, notebook: notebook)
        context.insert(newPage)
        notebook.pages.append(newPage)
        touch(notebook)
        try save()
        return newPage
    }

    public func deletePage(_ page: Page) throws {
        guard let notebook = page.notebook else { throw DocumentStoreError.notFound }
        let removedIndex = page.index
        notebook.pages.removeAll { $0.id == page.id }
        context.delete(page)
        // Close the gap so indices stay contiguous.
        for p in notebook.pages where p.index > removedIndex { p.index -= 1 }
        touch(notebook)
        try save()
    }

    public func movePage(_ page: Page, to index: Int) throws {
        guard let notebook = page.notebook else { throw DocumentStoreError.notFound }
        var ordered = notebook.orderedPages
        guard index >= 0, index < ordered.count else { throw DocumentStoreError.invalidIndex }
        ordered.removeAll { $0.id == page.id }
        ordered.insert(page, at: index)
        for (i, p) in ordered.enumerated() { p.index = i }
        touch(notebook)
        try save()
    }

    @discardableResult
    public func duplicatePage(_ page: Page) throws -> Page {
        guard let notebook = page.notebook else { throw DocumentStoreError.notFound }
        // addPage handles index insertion/shifting and saves.
        let copy = try addPage(to: notebook, after: page, template: page.template)
        copy.drawingData = page.drawingData
        copy.thumbnailData = page.thumbnailData
        try save()
        return copy
    }

    public func updateDrawing(for page: Page, drawingData: Data) throws {
        page.drawingData = drawingData
        page.modifiedAt = .now
        if let notebook = page.notebook { touch(notebook) }
        try save()
        // Refresh the cached thumbnail off the critical inking path: a low
        // priority main-actor task that tolerates rasterization failures and
        // never blocks the active stroke.
        refreshThumbnail(for: page)
    }

    // MARK: - Flashcard sets

    @discardableResult
    public func createFlashcardSet(title: String, in folder: Folder?) throws -> FlashcardSet {
        let count = try folder?.flashcardSets.count ?? rootFlashcardSets().count
        let set = FlashcardSet(title: title, folder: folder, sortIndex: count)
        context.insert(set)
        // Seed exactly one blank card at index 0.
        let firstCard = Flashcard(index: 0, set: set)
        context.insert(firstCard)
        set.cards.append(firstCard)
        if let folder {
            folder.flashcardSets.append(set)
            touch(folder)
        }
        try save()
        return set
    }

    public func renameFlashcardSet(_ set: FlashcardSet, to title: String) throws {
        set.title = title
        touch(set)
        try save()
    }

    public func deleteFlashcardSet(_ set: FlashcardSet) throws {
        // `.cascade` on `FlashcardSet.cards` removes the cards.
        context.delete(set)
        try save()
    }

    public func moveFlashcardSet(_ set: FlashcardSet, into folder: Folder?) throws {
        set.folder = folder
        if let folder {
            set.sortIndex = folder.flashcardSets.count
        } else {
            set.sortIndex = try rootFlashcardSets().count
        }
        touch(set)
        try save()
    }

    @discardableResult
    public func duplicateFlashcardSet(_ set: FlashcardSet) throws -> FlashcardSet {
        let copy = FlashcardSet(
            title: set.title + " copy",
            folder: set.folder,
            coverColorHex: set.coverColorHex,
            sortIndex: set.sortIndex + 1
        )
        context.insert(copy)
        // Deep-copy cards (text + both ink blobs) preserving order/index.
        for card in set.orderedCards {
            let c = Flashcard(
                index: card.index,
                frontText: card.frontText,
                backText: card.backText,
                set: copy
            )
            c.frontDrawingData = card.frontDrawingData
            c.backDrawingData = card.backDrawingData
            context.insert(c)
            copy.cards.append(c)
        }
        if let folder = set.folder {
            folder.flashcardSets.append(copy)
            touch(folder)
        }
        try save()
        return copy
    }

    // MARK: - Flashcards

    @discardableResult
    public func addCard(to set: FlashcardSet, after card: Flashcard?) throws -> Flashcard {
        let insertIndex = (card?.index).map { $0 + 1 } ?? set.cards.count
        // Shift following cards up to make room.
        for c in set.cards where c.index >= insertIndex { c.index += 1 }
        let newCard = Flashcard(index: insertIndex, set: set)
        context.insert(newCard)
        set.cards.append(newCard)
        touch(set)
        try save()
        return newCard
    }

    public func updateCard(
        _ card: Flashcard,
        frontText: String,
        backText: String,
        frontDrawing: Data?,
        backDrawing: Data?
    ) throws {
        card.frontText = frontText
        card.backText = backText
        card.frontDrawingData = frontDrawing
        card.backDrawingData = backDrawing
        card.modifiedAt = .now
        if let set = card.set { touch(set) }
        try save()
    }

    public func deleteCard(_ card: Flashcard) throws {
        guard let set = card.set else { throw DocumentStoreError.notFound }
        let removedIndex = card.index
        set.cards.removeAll { $0.id == card.id }
        context.delete(card)
        // Close the gap so indices stay contiguous.
        for c in set.cards where c.index > removedIndex { c.index -= 1 }
        touch(set)
        try save()
    }

    public func moveCard(_ card: Flashcard, to index: Int) throws {
        guard let set = card.set else { throw DocumentStoreError.notFound }
        var ordered = set.orderedCards
        guard index >= 0, index < ordered.count else { throw DocumentStoreError.invalidIndex }
        ordered.removeAll { $0.id == card.id }
        ordered.insert(card, at: index)
        for (i, c) in ordered.enumerated() { c.index = i }
        touch(set)
        try save()
    }

    public func save() throws {
        do {
            try context.save()
        } catch {
            throw DocumentStoreError.persistenceFailure(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func touch(_ folder: Folder) { folder.modifiedAt = .now }
    private func touch(_ notebook: Notebook) { notebook.modifiedAt = .now }
    private func touch(_ set: FlashcardSet) { set.modifiedAt = .now }

    /// Root folders (no parent), ordered by `sortIndex`.
    private func rootFolders() throws -> [Folder] {
        let descriptor = FetchDescriptor<Folder>(
            predicate: #Predicate { $0.parent == nil },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw DocumentStoreError.persistenceFailure(error.localizedDescription)
        }
    }

    /// Root notebooks (not in any folder), ordered by `sortIndex`.
    private func rootNotebooks() throws -> [Notebook] {
        let descriptor = FetchDescriptor<Notebook>(
            predicate: #Predicate { $0.folder == nil },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw DocumentStoreError.persistenceFailure(error.localizedDescription)
        }
    }

    /// Root flashcard sets (not in any folder), ordered by `sortIndex`.
    private func rootFlashcardSets() throws -> [FlashcardSet] {
        let descriptor = FetchDescriptor<FlashcardSet>(
            predicate: #Predicate { $0.folder == nil },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            throw DocumentStoreError.persistenceFailure(error.localizedDescription)
        }
    }

    /// Renders and caches `page.thumbnailData` asynchronously. Failures are
    /// swallowed: a stale or missing thumbnail must never break inking.
    private func refreshThumbnail(for page: Page) {
        let template = page.template
        let drawingData = page.drawingData
        Task(priority: .utility) { @MainActor [weak self, weak page] in
            guard let self, let page else { return }
            do {
                let data = try self.thumbnails.renderShelfThumbnail(
                    drawingData: drawingData,
                    template: template
                )
                page.thumbnailData = data
                try? self.context.save()
            } catch {
                // Tolerate thumbnail failures — leave the previous cache intact.
            }
        }
    }
}
