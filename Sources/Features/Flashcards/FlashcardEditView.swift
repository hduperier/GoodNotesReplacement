import SwiftUI

/// Edits one flashcard: typed text for the front and back, plus an optional
/// handwritten ink drawing per side. A segmented control switches between the
/// two sides so the (large) ink canvas only needs to render one at a time.
@MainActor
struct FlashcardEditView: View {
    let card: Flashcard
    /// Called after each persisted change so the parent list can refresh.
    let onChange: () -> Void

    @Environment(\.documentStore) private var store

    @State private var side: Side = .front
    @State private var frontText: String
    @State private var backText: String
    @State private var frontDrawing: Data?
    @State private var backDrawing: Data?
    @State private var showFrontInk: Bool
    @State private var showBackInk: Bool

    // Stable canvas identities so switching sides reloads the right ink.
    @State private var frontCanvasID = UUID()
    @State private var backCanvasID = UUID()

    /// A simple square, blank-white "paper" for the card ink canvas.
    private static let cardTemplate = PaperTemplate(name: "Card", style: .blank, size: .square)

    init(card: Flashcard, onChange: @escaping () -> Void) {
        self.card = card
        self.onChange = onChange
        _frontText = State(initialValue: card.frontText)
        _backText = State(initialValue: card.backText)
        _frontDrawing = State(initialValue: card.frontDrawingData)
        _backDrawing = State(initialValue: card.backDrawingData)
        _showFrontInk = State(initialValue: !(card.frontDrawingData?.isEmpty ?? true))
        _showBackInk = State(initialValue: !(card.backDrawingData?.isEmpty ?? true))
    }

    var body: some View {
        Form {
            Picker("Side", selection: $side) {
                Text("Front").tag(Side.front)
                Text("Back").tag(Side.back)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("cardEdit.sidePicker")

            switch side {
            case .front:
                sideEditor(
                    title: "Front",
                    text: $frontText,
                    showInk: $showFrontInk,
                    drawing: $frontDrawing,
                    canvasID: frontCanvasID,
                    identifierPrefix: "cardEdit.front"
                )
            case .back:
                sideEditor(
                    title: "Back",
                    text: $backText,
                    showInk: $showBackInk,
                    drawing: $backDrawing,
                    canvasID: backCanvasID,
                    identifierPrefix: "cardEdit.back"
                )
            }
        }
        .navigationTitle("Edit Card")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { persist() }
    }

    @ViewBuilder
    private func sideEditor(
        title: String,
        text: Binding<String>,
        showInk: Binding<Bool>,
        drawing: Binding<Data?>,
        canvasID: UUID,
        identifierPrefix: String
    ) -> some View {
        Section(title) {
            TextField("Type text…", text: text, axis: .vertical)
                .lineLimit(2...5)
                .accessibilityIdentifier("\(identifierPrefix).text")
                .onChange(of: text.wrappedValue) { persist() }
        }

        Section {
            Toggle("Handwritten drawing", isOn: showInk)
                .accessibilityIdentifier("\(identifierPrefix).inkToggle")
                .onChange(of: showInk.wrappedValue) { _, isOn in
                    if !isOn { drawing.wrappedValue = nil; persist() }
                }

            if showInk.wrappedValue {
                PencilKitCanvasView(
                    pageID: canvasID,
                    drawingData: drawing.wrappedValue,
                    template: Self.cardTemplate,
                    tool: .defaultPen
                ) { data in
                    drawing.wrappedValue = data
                    persist()
                }
                .frame(height: 260)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                )
                .accessibilityIdentifier("\(identifierPrefix).canvas")
            }
        }
    }

    private func persist() {
        try? store.updateCard(
            card,
            frontText: frontText,
            backText: backText,
            frontDrawing: showFrontInk ? frontDrawing : nil,
            backDrawing: showBackInk ? backDrawing : nil
        )
        try? store.save()
        onChange()
    }

    private enum Side: Hashable { case front, back }
}
