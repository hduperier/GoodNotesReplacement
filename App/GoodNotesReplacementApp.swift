import SwiftUI
import SwiftData

@main
struct GoodNotesReplacementApp: App {
    private let container: ModelContainer

    init() {
        do {
            // Local-only on-device store (no CloudKit). The file lives in the
            // app's Application Support directory.
            container = try ModelContainer(
                for: AppSchema.schema,
                configurations: ModelConfiguration("GoodNotesReplacement")
            )
        } catch {
            fatalError("Unable to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
