import SwiftUI
import SwiftData

/// Root of the app. Presents the library inside an iPad-class
/// `NavigationSplitView`: a sidebar listing the root + folders, and a detail
/// column hosting the shelf (which itself pushes into folders / the editor).
///
/// The `DocumentStore` and `ThumbnailService` are read from the environment.
/// Until the orchestrator injects the real `SwiftDataDocumentStore`, the
/// `Environment+Stores` defaults (`InMemoryDocumentStore` / `PKThumbnailService`)
/// keep the app and previews running.
struct RootView: View {
    var body: some View {
        LibraryRootView()
    }
}

#Preview {
    RootView()
        .documentStore(InMemoryDocumentStore(seed: true))
        .modelContainer(try! AppSchema.previewContainer())
}
