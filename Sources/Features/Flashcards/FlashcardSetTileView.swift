import SwiftUI

/// A single flashcard-set tile on the shelf: a stacked-cards cover in the set's
/// cover color, title and card count. Reads differently from a notebook tile.
@MainActor
struct FlashcardSetTileView: View {
    let set: FlashcardSet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color(hex: set.coverColorHex)
                    .aspectRatio(0.75, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(.separator), lineWidth: 0.5)
                    )

                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

            Text(set.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text("^[\(set.cardCount) card](inflect: true)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(set.title), \(set.cardCount) cards")
    }
}
