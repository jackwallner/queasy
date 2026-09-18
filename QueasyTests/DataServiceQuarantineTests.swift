import Foundation
import Testing
@testable import Queasy

struct DataServiceQuarantineTests {
    @Test func unreadableStoreIsMovedAsideNotDeleted() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = dir.appendingPathComponent("Queasy.store")
        let wal = URL(fileURLWithPath: store.path + "-wal")
        try Data("episodes".utf8).write(to: store)
        try Data("wal".utf8).write(to: wal)

        let moved = DataService.quarantineStore(at: store)

        #expect(moved.count == 2)
        #expect(!FileManager.default.fileExists(atPath: store.path))
        #expect(!FileManager.default.fileExists(atPath: wal.path))
        let copy = try #require(moved.first { !$0.lastPathComponent.contains("-wal") })
        #expect(copy.lastPathComponent.hasPrefix("Queasy.store.corrupt-"))
        #expect(try Data(contentsOf: copy) == Data("episodes".utf8))
    }

    @Test func missingStoreQuarantinesNothing() {
        let store = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Queasy.store")
        #expect(DataService.quarantineStore(at: store).isEmpty)
    }
}
