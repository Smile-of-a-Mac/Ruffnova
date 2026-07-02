import XCTest
@testable import Ruffnova

@MainActor
final class CollectionServiceTests: XCTestCase {
    func testCreateRenameAndPersistCollection() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storageURL = directory.appendingPathComponent("collections.json")
        let service = CollectionService(storageURL: storageURL)

        let created = try XCTUnwrap(service.create(name: " Games "))
        service.rename(created.id, to: "Arcade")

        let reloaded = CollectionService(storageURL: storageURL)

        XCTAssertEqual(reloaded.collections.count, 1)
        XCTAssertEqual(reloaded.collections.first?.name, "Arcade")
    }

    func testCollectionMembershipDoesNotDuplicateItems() throws {
        let service = CollectionService(storageURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let collection = try XCTUnwrap(service.create(name: "Favorites"))
        let itemID = UUID()

        service.add(itemID, to: collection.id)
        service.add(itemID, to: collection.id)

        XCTAssertEqual(service.collection(with: collection.id)?.itemIDs, [itemID])
        XCTAssertTrue(service.collections(containing: itemID).contains { $0.id == collection.id })

        service.remove(itemID, from: collection.id)

        XCTAssertEqual(service.collection(with: collection.id)?.itemIDs, [])
    }
}
