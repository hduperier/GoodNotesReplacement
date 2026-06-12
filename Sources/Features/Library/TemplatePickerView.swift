import SwiftUI

/// A grid of selectable paper templates, reused by the new-notebook flow and the
/// add-page flow. Shows a live paper preview for each built-in template.
struct TemplatePickerView: View {
    @Binding var selection: PaperTemplate
    var templates: [PaperTemplate] = PaperTemplate.builtIns

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(templates) { template in
                Button {
                    selection = template
                } label: {
                    VStack(spacing: 6) {
                        PaperSwatch(template: template)
                            .aspectRatio(template.canvasSize.width / template.canvasSize.height,
                                         contentMode: .fit)
                            .frame(height: 110)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        isSelected(template) ? Color.accentColor : Color(.separator),
                                        lineWidth: isSelected(template) ? 3 : 1
                                    )
                            )
                        Text(template.style.displayName)
                            .font(.caption)
                            .foregroundStyle(isSelected(template) ? Color.accentColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("template.\(template.style.rawValue)")
                .accessibilityAddTraits(isSelected(template) ? [.isSelected] : [])
            }
        }
    }

    private func isSelected(_ template: PaperTemplate) -> Bool {
        template.style == selection.style && template.size == selection.size
    }
}

/// A small live render of a paper template using the SwiftUI Canvas, mirroring
/// `PaperRenderer`'s output closely enough for a picker preview.
private struct PaperSwatch: View {
    let template: PaperTemplate

    var body: some View {
        Canvas { context, size in
            let bg = Color(hex: template.backgroundColorHex)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bg))

            let lineColor = Color(hex: template.lineColorHex)
            // Scale the template's point spacing into the swatch.
            let scale = size.height / max(1, template.canvasSize.height)
            let spacing = max(4, CGFloat(template.lineSpacing) * scale)

            switch template.style {
            case .blank:
                break
            case .lined, .cornell:
                drawHLines(context, size: size, spacing: spacing, color: lineColor)
            case .grid:
                drawHLines(context, size: size, spacing: spacing, color: lineColor)
                drawVLines(context, size: size, spacing: spacing, color: lineColor)
            case .dotted:
                drawDots(context, size: size, spacing: spacing, color: lineColor)
            case .isometric:
                drawVLines(context, size: size, spacing: spacing, color: lineColor)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func drawHLines(_ ctx: GraphicsContext, size: CGSize, spacing: CGFloat, color: Color) {
        var y = spacing
        var path = Path()
        while y < size.height {
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }
        ctx.stroke(path, with: .color(color), lineWidth: 0.5)
    }

    private func drawVLines(_ ctx: GraphicsContext, size: CGSize, spacing: CGFloat, color: Color) {
        var x = spacing
        var path = Path()
        while x < size.width {
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }
        ctx.stroke(path, with: .color(color), lineWidth: 0.5)
    }

    private func drawDots(_ ctx: GraphicsContext, size: CGSize, spacing: CGFloat, color: Color) {
        var y = spacing
        while y < size.height {
            var x = spacing
            while x < size.width {
                let r: CGFloat = 0.8
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(color))
                x += spacing
            }
            y += spacing
        }
    }
}

#Preview {
    @Previewable @State var selection: PaperTemplate = .lined
    return ScrollView {
        TemplatePickerView(selection: $selection)
            .padding()
    }
}
