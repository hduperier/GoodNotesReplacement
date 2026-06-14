import XCTest
import SwiftData
@testable import GoodNotesReplacement

@MainActor
final class AppSchemaTests: XCTestCase {

    func test_models_listIncludesAllPersistentTypes() {
        let names = AppSchema.models.map { String(describing: $0) }
        XCTAssertTrue(names.contains("Folder"))
        XCTAssertTrue(names.contains("Notebook"))
        XCTAssertTrue(names.contains("Page"))
        XCTAssertTrue(names.contains("FlashcardSet"))
        XCTAssertTrue(names.contains("Flashcard"))
        XCTAssertEqual(AppSchema.models.count, 5)
    }

    func test_schema_buildsFromModels() {
        let schema = AppSchema.schema
        // A valid schema lists one entity per registered model.
        XCTAssertEqual(schema.entities.count, AppSchema.models.count)
        let entityNames = Set(schema.entities.map(\.name))
        XCTAssertTrue(entityNames.isSuperset(
            of: ["Folder", "Notebook", "Page", "FlashcardSet", "Flashcard"]))
    }

    func test_previewContainer_buildsAndIsUsable() throws {
        let container = try AppSchema.previewContainer()
        let context = container.mainContext

        // Insert and fetch to prove the container's model graph is wired up.
        let notebook = Notebook(title: "Smoke", defaultTemplate: .lined)
        context.insert(notebook)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Notebook>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Smoke")
    }

    func test_previewContainer_isInMemory_isolatedBetweenInstances() throws {
        let containerA = try AppSchema.previewContainer()
        containerA.mainContext.insert(Notebook(title: "A"))
        try containerA.mainContext.save()

        // A separate in-memory container must not see the other's data.
        let containerB = try AppSchema.previewContainer()
        let fetchedB = try containerB.mainContext.fetch(FetchDescriptor<Notebook>())
        XCTAssertTrue(fetchedB.isEmpty, "Each preview container should be isolated.")
    }

    func test_cascadeRelationships_modelLevel() throws {
        // Verify the model-level cascade by exercising the container directly,
        // independent of any DocumentStore implementation.
        let container = try AppSchema.previewContainer()
        let context = container.mainContext

        let folder = Folder(name: "F")
        let notebook = Notebook(title: "N", folder: folder)
        let page = Page(index: 0, template: .lined, notebook: notebook)
        notebook.pages.append(page)
        folder.notebooks.append(notebook)
        context.insert(folder)
        try context.save()

        context.delete(folder)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Notebook>()).isEmpty,
                      "Deleting a folder should cascade to notebooks.")
        XCTAssertTrue(try context.fetch(FetchDescriptor<Page>()).isEmpty,
                      "Deleting a folder should cascade to pages.")
    }
}
