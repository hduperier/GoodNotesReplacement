import SwiftUI
import UIKit

/// Modal flow to create a notebook: title, cover color, and a paper template.
struct NewNotebookView: View {
    /// Folder the notebook is created in (nil = root library).
    let folder: Folder?
    /// Called with the chosen values when the user taps Create.
    let onCreate: (_ title: String, _ template: PaperTemplate, _ coverHex: String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var template: PaperTemplate = .lined
    @State private var coverColor: Color = Color(hex: "#4E6E8E")

    private let coverChoices = ["#4E6E8E", "#B5503C", "#3C7A4F", "#6B4E8E", "#C9962A", "#2C2C2E"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Notebook title", text: $title)
                        .accessibilityIdentifier("newNotebook.titleField")
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
                                .accessibilityIdentifier("newNotebook.cover.\(hex)")
                        }
                        ColorPicker("", selection: $coverColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                }

                Section("Paper") {
                    TemplatePickerView(selection: $template)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(finalTitle.isEmpty ? "Untitled" : finalTitle,
                                 template,
                                 coverColor.toHex())
                        dismiss()
                    }
                    .accessibilityIdentifier("newNotebook.createButton")
                }
            }
        }
    }

    private var selectedCover: String { coverColor.toHex() }
}

extension Color {
    /// Best-effort `#RRGGBB` serialization of a SwiftUI color.
    func toHex() -> String {
        UIColor(self).hexString
    }
}

#Preview {
    NewNotebookView(folder: nil) { _, _, _ in }
}
