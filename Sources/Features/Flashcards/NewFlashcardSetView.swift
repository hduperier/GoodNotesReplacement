import SwiftUI

/// Modal flow to create a flashcard set: a title and a cover color. Unlike a
/// notebook, a set has no paper template.
struct NewFlashcardSetView: View {
    /// Folder the set is created in (nil = root library).
    let folder: Folder?
    /// Called with the chosen values when the user taps Create.
    let onCreate: (_ title: String, _ coverHex: String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var coverColor: Color = Color(hex: "#C9962A")

    private let coverChoices = ["#C9962A", "#4E6E8E", "#B5503C", "#3C7A4F", "#6B4E8E", "#2C2C2E"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Set title", text: $title)
                        .accessibilityIdentifier("newFlashcardSet.titleField")
                }

                Section("Cover") {
                    HStack(spacing: 12) {
                        ForEach(coverChoices, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().strokeBorder(.primary.opacity(selectedCover == hex ? 0.8 : 0),
                                                          lineWidth: 2)
                                )
                                .onTapGesture { coverColor = Color(hex: hex) }
                                .accessibilityIdentifier("newFlashcardSet.cover.\(hex)")
                        }
                        ColorPicker("", selection: $coverColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
            }
            .navigationTitle("New Flashcard Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(finalTitle.isEmpty ? "Untitled" : finalTitle,
                                 coverColor.toHex())
                        dismiss()
                    }
                    .accessibilityIdentifier("newFlashcardSet.createButton")
                }
            }
        }
    }

    private var selectedCover: String { coverColor.toHex() }
}

#Preview {
    NewFlashcardSetView(folder: nil) { _, _ in }
}
