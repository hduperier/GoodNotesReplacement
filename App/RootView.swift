import SwiftUI

/// Placeholder root view. The FRONTEND agent replaces this body with the real
/// library/shelf experience (`LibraryView`) and notebook editor navigation.
/// Keep the type name `RootView` so `GoodNotesReplacementApp` continues to compile.
struct RootView: View {
    var body: some View {
        ContentUnavailableView(
            "GoodNotes Replacement",
            systemImage: "books.vertical",
            description: Text("Foundation scaffolded. Frontend UI pending.")
        )
    }
}

#Preview {
    RootView()
}
