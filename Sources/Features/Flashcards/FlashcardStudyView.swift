import SwiftUI
import PencilKit

/// Quizlet-style study runner. Cards are studied in random order; tap a card to
/// flip it; mark each "Know" or "Still learning". Still-learning cards are
/// re-queued so they come back around until everything is known. All progress is
/// session-only — nothing is written back to the store.
@MainActor
struct FlashcardStudyView: View {
    let set: FlashcardSet

    @Environment(\.dismiss) private var dismiss

    /// Upcoming cards for this round; `queue.first` is on screen.
    @State private var queue: [Flashcard] = []
    @State private var isShowingBack = false
    @State private var masteredCount = 0
    @State private var stillLearningTaps = 0

    private var total: Int { self.set.cardCount }

    var body: some View {
        NavigationStack {
            Group {
                if queue.isEmpty {
                    summary
                } else {
                    studyArea
                }
            }
            .navigationTitle(set.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("study.doneButton")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startRound()
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .accessibilityIdentifier("study.shuffleButton")
                }
            }
        }
        .onAppear { if queue.isEmpty && masteredCount == 0 { startRound() } }
    }

    // MARK: - Study area

    @ViewBuilder
    private var studyArea: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(masteredCount), total: Double(max(total, 1))) {
                Text("Mastered \(masteredCount) of \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            if let card = queue.first {
                CardFaceView(card: card, showingBack: isShowingBack)
                    .id(card.id)
                    .onTapGesture { flip() }
                    .accessibilityIdentifier("study.card")
                    .accessibilityHint("Double tap to flip")
            }

            Spacer(minLength: 0)

            HStack(spacing: 16) {
                gradeButton(
                    title: "Still learning",
                    systemImage: "arrow.counterclockwise",
                    tint: .orange,
                    identifier: "study.stillLearningButton"
                ) { grade(known: false) }

                gradeButton(
                    title: "Know",
                    systemImage: "checkmark",
                    tint: .green,
                    identifier: "study.knowButton"
                ) { grade(known: true) }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
    }

    private func gradeButton(
        title: String,
        systemImage: String,
        tint: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Summary

    private var summary: some View {
        ContentUnavailableView {
            Label("Round complete", systemImage: "checkmark.seal.fill")
        } description: {
            Text(total == 0
                 ? "This set has no cards yet."
                 : "You mastered all \(total) cards. Still-learning taps this round: \(stillLearningTaps).")
        } actions: {
            if total > 0 {
                Button("Study again") { startRound() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("study.studyAgainButton")
            }
            Button("Done") { dismiss() }
        }
    }

    // MARK: - Logic

    private func startRound() {
        queue = set.orderedCards.shuffled()
        isShowingBack = false
        masteredCount = 0
        stillLearningTaps = 0
    }

    private func flip() {
        withAnimation(.easeInOut(duration: 0.25)) { isShowingBack.toggle() }
    }

    private func grade(known: Bool) {
        guard !queue.isEmpty else { return }
        let card = queue.removeFirst()
        if known {
            masteredCount += 1
        } else {
            stillLearningTaps += 1
            queue.append(card) // comes back around
        }
        isShowingBack = false
    }
}

/// One face of a card: typed text and/or its handwritten ink. Flips with a 3D
/// rotation; back-face content is counter-rotated so it never reads mirrored.
@MainActor
private struct CardFaceView: View {
    let card: Flashcard
    let showingBack: Bool

    var body: some View {
        let text = showingBack ? card.backText : card.frontText
        let ink = showingBack ? card.backDrawingData : card.frontDrawingData

        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )
            .overlay {
                VStack(spacing: 16) {
                    Text(showingBack ? "BACK" : "FRONT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        Text(trimmed)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                    }
                    if let image = Self.image(from: ink) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                    }
                    if trimmed.isEmpty && ink == nil {
                        Text("(empty)").foregroundStyle(.tertiary)
                    }
                }
                .padding(28)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            .frame(maxWidth: 520)
            .aspectRatio(1.5, contentMode: .fit)
            .padding(.horizontal, 24)
            // Flip: rotate the whole face; counter-rotate the back so text reads
            // correctly once flipped.
            .rotation3DEffect(.degrees(showingBack ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(showingBack ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    private static func image(from data: Data?) -> Image? {
        guard let data, !data.isEmpty,
              let drawing = try? PKDrawing(data: data),
              !drawing.bounds.isEmpty else { return nil }
        let uiImage = drawing.image(from: drawing.bounds, scale: 2.0)
        return Image(uiImage: uiImage)
    }
}

#Preview {
    let store = InMemoryDocumentStore(seed: true)
    let set = store.rootFlashcardSets.first!
    return FlashcardStudyView(set: set)
}
