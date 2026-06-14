import SwiftUI

/// The set's edit screen: a reorderable list of cards with add/delete, an entry
/// into per-card editing, and a Study button that launches the study runner.
@MainActor
struct FlashcardSetEditorView: View {
    let set: FlashcardSet

    @Environment(\.documentStore) private var store

    /// Bumped after every mutation so the in-memory store's plain arrays (not
    /// `@Query`-observed) are re-read. Harmless for the real store.
    @State private var refreshToken = 0
    @State private var editMode: EditMode = .inactive
    @State private var showingStudy = false

    var body: some View {
        let _ = refreshToken
        List {
            if cards.isEmpty {
                emptyState
            } else {
                ForEach(cards) { card in
                    NavigationLink(value: card) {
                        cardRow(card)
                    }
                    .accessibilityIdentifier("setEditor.card.\(card.id.uuidString)")
                }
                .onDelete(perform: deleteCards)
                .onMove(perform: moveCards)
            }
        }
        .navigationTitle(set.title)
        .navigationDestination(for: Flashcard.self) { card in
            FlashcardEditView(card: card) { bump() }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingStudy = true
                } label: {
                    Label("Study", systemImage: "play.fill")
                }
                .disabled(cards.isEmpty)
                .accessibilityIdentifier("setEditor.studyButton")
            }
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addCard()
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
                .accessibilityIdentifier("setEditor.addCardButton")
            }
        }
        .fullScreenCover(isPresented: $showingStudy) {
            FlashcardStudyView(set: set)
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func cardRow(_ card: Flashcard) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayText(card.frontText, ink: card.frontDrawingData, fallback: "Front"))
                .font(.body)
                .lineLimit(1)
            Text(displayText(card.backText, ink: card.backDrawingData, fallback: "Back"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func displayText(_ text: String, ink: Data?, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !(ink?.isEmpty ?? true) { return "✏︎ (drawing)" }
        return fallback
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Cards", systemImage: "rectangle.on.rectangle.angled")
        } description: {
            Text("Tap + to add your first card.")
        } actions: {
            Button("Add Card") { addCard() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Reads

    private var cards: [Flashcard] { self.set.orderedCards }

    // MARK: - Mutations

    private func addCard() {
        try? store.addCard(to: set, after: nil)
        try? store.save()
        bump()
    }

    private func deleteCards(at offsets: IndexSet) {
        let ordered = cards
        for index in offsets where index < ordered.count {
            try? store.deleteCard(ordered[index])
        }
        try? store.save()
        bump()
    }

    private func moveCards(from source: IndexSet, to destination: Int) {
        var ordered = cards
        guard let movedCardID = source.first.map({ ordered[$0].id }) else { return }
        ordered.move(fromOffsets: source, toOffset: destination)
        guard let newIndex = ordered.firstIndex(where: { $0.id == movedCardID }),
              let card = cards.first(where: { $0.id == movedCardID }) else { return }
        try? store.moveCard(card, to: newIndex)
        try? store.save()
        bump()
    }

    private func bump() { refreshToken &+= 1 }
}

#Preview {
    let store = InMemoryDocumentStore(seed: true)
    let set = store.rootFlashcardSets.first!
    return NavigationStack {
        FlashcardSetEditorView(set: set)
    }
    .documentStore(store)
    .modelContainer(try! AppSchema.previewContainer())
}
