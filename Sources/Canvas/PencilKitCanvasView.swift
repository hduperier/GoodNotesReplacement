import SwiftUI
import PencilKit

/// SwiftUI wrapper around `PKCanvasView`.
///
/// Responsibilities:
/// - Loads `drawingData` into a `PKDrawing` and keeps the canvas in sync when
///   the bound page changes.
/// - Applies the current `InkTool` (via `ToolMapper`).
/// - Reports drawing edits back through `onDrawingChanged`, **debounced** by
///   `debounceInterval` (≈0.7s of idle) so we don't thrash the store mid-stroke.
/// - Exposes undo/redo through the canvas's `undoManager` (driven by the parent
///   via the `UndoController`).
/// - Allows pinch-zoom and two-finger pan.
public struct PencilKitCanvasView: UIViewRepresentable {

    /// Serialized drawing for the page being shown. Changing the `pageID`
    /// triggers a reload of the canvas content.
    public let pageID: UUID
    public let drawingData: Data?

    /// The paper template, used to size the canvas content area.
    public let template: PaperTemplate

    /// The currently selected tool.
    public let tool: InkTool

    /// Whether the user can draw (false while presenting modals, etc.).
    public let isRulerActive: Bool

    /// Debounce window before a change is reported (seconds).
    public let debounceInterval: TimeInterval

    /// Called with `PKDrawing.dataRepresentation()` after edits settle.
    public let onDrawingChanged: (Data) -> Void

    /// Optional hook to surface the canvas's `UndoManager` to the parent so the
    /// toolbar's undo/redo buttons can drive it.
    public let undoController: UndoController?

    public init(
        pageID: UUID,
        drawingData: Data?,
        template: PaperTemplate,
        tool: InkTool,
        isRulerActive: Bool = false,
        debounceInterval: TimeInterval = 0.7,
        undoController: UndoController? = nil,
        onDrawingChanged: @escaping (Data) -> Void
    ) {
        self.pageID = pageID
        self.drawingData = drawingData
        self.template = template
        self.tool = tool
        self.isRulerActive = isRulerActive
        self.debounceInterval = debounceInterval
        self.undoController = undoController
        self.onDrawingChanged = onDrawingChanged
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        // Accept finger input too so QA's synthesized UI-test swipes register;
        // real users get Pencil-quality input automatically.
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false

        // Zoom / pan.
        canvas.minimumZoomScale = 1.0
        canvas.maximumZoomScale = 4.0
        canvas.bouncesZoom = true
        canvas.contentSize = template.canvasSize

        canvas.accessibilityIdentifier = "editor.canvas"
        canvas.isAccessibilityElement = true

        // Initial content.
        context.coordinator.loadDrawing(into: canvas, data: drawingData)
        context.coordinator.applyTool(tool, to: canvas)
        canvas.isRulerActive = isRulerActive

        undoController?.bind(canvas.undoManager)
        return canvas
    }

    public func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        // Reload only when the page identity changed (switching pages), to avoid
        // clobbering in-progress edits on the same page. Flush any pending
        // debounced edit for the outgoing page first so nothing is lost.
        if coordinator.loadedPageID != pageID {
            coordinator.flushPendingChange()
            coordinator.loadDrawing(into: canvas, data: drawingData)
            undoController?.bind(canvas.undoManager)
        }

        coordinator.applyTool(tool, to: canvas)
        if canvas.isRulerActive != isRulerActive {
            canvas.isRulerActive = isRulerActive
        }
        if canvas.contentSize != template.canvasSize {
            canvas.contentSize = template.canvasSize
        }
    }

    public static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.flushPendingChange()
    }

    // MARK: - Coordinator

    @MainActor
    public final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilKitCanvasView
        private(set) var loadedPageID: UUID?
        private var debounceWorkItem: DispatchWorkItem?
        /// True while we are programmatically setting `canvas.drawing` so the
        /// resulting delegate callback doesn't trigger a spurious save.
        private var isLoadingProgrammatically = false
        private weak var canvasRef: PKCanvasView?

        init(parent: PencilKitCanvasView) {
            self.parent = parent
        }

        func loadDrawing(into canvas: PKCanvasView, data: Data?) {
            canvasRef = canvas
            isLoadingProgrammatically = true
            defer { isLoadingProgrammatically = false }

            if let data, !data.isEmpty, let drawing = try? PKDrawing(data: data) {
                canvas.drawing = drawing
            } else {
                canvas.drawing = PKDrawing()
            }
            loadedPageID = parent.pageID
            debounceWorkItem?.cancel()
            debounceWorkItem = nil
        }

        func applyTool(_ tool: InkTool, to canvas: PKCanvasView) {
            canvas.tool = ToolMapper.pkTool(for: tool)
        }

        public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isLoadingProgrammatically else { return }
            canvasRef = canvasView
            scheduleChange(from: canvasView)
        }

        private func scheduleChange(from canvas: PKCanvasView) {
            debounceWorkItem?.cancel()
            let drawing = canvas.drawing
            let callback = parent.onDrawingChanged
            let work = DispatchWorkItem {
                callback(drawing.dataRepresentation())
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + parent.debounceInterval, execute: work)
        }

        /// Fire any pending debounced change immediately (e.g. on teardown or
        /// when navigating away from the page).
        func flushPendingChange() {
            guard let work = debounceWorkItem else { return }
            work.cancel()
            debounceWorkItem = nil
            // Execute synchronously so the latest ink is captured before the view
            // disappears.
            work.perform()
        }
    }
}

/// A small reference type the parent holds to drive undo/redo on whatever
/// `PKCanvasView` is currently on screen. The canvas binds its `UndoManager`
/// into this controller; the toolbar calls `undo()`/`redo()`.
@MainActor
public final class UndoController: ObservableObject {
    private weak var undoManager: UndoManager?

    public init() {}

    public func bind(_ manager: UndoManager?) {
        undoManager = manager
        objectWillChange.send()
    }

    public var canUndo: Bool { undoManager?.canUndo ?? false }
    public var canRedo: Bool { undoManager?.canRedo ?? false }

    public func undo() {
        undoManager?.undo()
        objectWillChange.send()
    }

    public func redo() {
        undoManager?.redo()
        objectWillChange.send()
    }
}
