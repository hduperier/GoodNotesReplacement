import SwiftUI
import UIKit

/// The editor's drawing toolbar: tool picker, color swatches + custom color,
/// width control, and undo/redo. Binds to the editor's `InkTool` state.
@MainActor
struct ToolbarView: View {
    @Binding var tool: InkTool
    let swatches: [String]
    @ObservedObject var undo: UndoController
    let onUndo: () -> Void
    let onRedo: () -> Void

    @State private var customColor: Color = .black
    @State private var showingWidth = false

    var body: some View {
        HStack(spacing: 16) {
            toolButtons
            Divider().frame(height: 28)
            colorControls
            Divider().frame(height: 28)
            widthControl
            Spacer(minLength: 8)
            undoRedo
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Tools

    private var toolButtons: some View {
        HStack(spacing: 8) {
            ForEach(InkToolKind.allCases, id: \.self) { kind in
                Button {
                    selectTool(kind)
                } label: {
                    Image(systemName: symbol(for: kind))
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(tool.kind == kind ? Color.accentColor.opacity(0.2) : .clear)
                        )
                        .foregroundStyle(tool.kind == kind ? Color.accentColor : .primary)
                }
                .accessibilityIdentifier("tool.\(kind.rawValue)")
                .accessibilityAddTraits(tool.kind == kind ? [.isSelected] : [])
                .help(kind.displayName)
            }
        }
    }

    private func symbol(for kind: InkToolKind) -> String {
        switch kind {
        case .pen: "pencil.tip"
        case .pencil: "pencil"
        case .marker: "highlighter"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .lasso: "lasso"
        }
    }

    private func selectTool(_ kind: InkToolKind) {
        tool.kind = kind
        // Sensible per-tool default widths the first time a tool is chosen.
        switch kind {
        case .pen: tool.width = max(1, min(tool.width, 6))
        case .pencil: tool.width = max(1, min(tool.width, 6))
        case .marker: tool.width = max(6, tool.width)
        case .highlighter: tool.width = max(14, tool.width)
        case .eraser, .lasso: break
        }
    }

    // MARK: - Color

    @ViewBuilder
    private var colorControls: some View {
        if tool.kind.isInking {
            HStack(spacing: 8) {
                ForEach(swatches, id: \.self) { hex in
                    Button {
                        tool.colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().strokeBorder(.primary.opacity(isSelectedColor(hex) ? 0.9 : 0.15),
                                                      lineWidth: isSelectedColor(hex) ? 2.5 : 1)
                            )
                    }
                    .accessibilityIdentifier("color.\(hex)")
                }
                ColorPicker("", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28)
                    .onChange(of: customColor) { _, newValue in
                        tool.colorHex = UIColor(newValue).hexString
                    }
                    .accessibilityIdentifier("color.custom")
            }
        } else {
            // Eraser scope toggle stands in for color when erasing.
            if tool.kind == .eraser {
                Picker("Eraser", selection: $tool.eraserKind) {
                    Text("Stroke").tag(EraserKind.vector)
                    Text("Pixel").tag(EraserKind.bitmap)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .accessibilityIdentifier("eraser.scope")
            }
        }
    }

    private func isSelectedColor(_ hex: String) -> Bool {
        hex.caseInsensitiveCompare(tool.colorHex) == .orderedSame
    }

    // MARK: - Width

    @ViewBuilder
    private var widthControl: some View {
        if tool.kind != .lasso {
            Menu {
                Slider(value: $tool.width, in: widthRange, step: 1)
                Text("\(Int(tool.width)) pt").font(.caption)
            } label: {
                Label("\(Int(tool.width)) pt", systemImage: "lineweight")
                    .labelStyle(.titleAndIcon)
            }
            .accessibilityIdentifier("tool.width")
        }
    }

    private var widthRange: ClosedRange<Double> {
        switch tool.kind {
        case .highlighter: 8...40
        case .marker: 4...30
        case .eraser: 6...60
        default: 1...20
        }
    }

    // MARK: - Undo / redo

    private var undoRedo: some View {
        HStack(spacing: 8) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!undo.canUndo)
            .accessibilityIdentifier("editor.undo")

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!undo.canRedo)
            .accessibilityIdentifier("editor.redo")
        }
    }
}

#Preview {
    @Previewable @State var tool = InkTool.defaultPen
    return ToolbarView(
        tool: $tool,
        swatches: ColorSwatches.starter,
        undo: UndoController(),
        onUndo: {},
        onRedo: {}
    )
}
