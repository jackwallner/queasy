import Foundation
import SwiftData
import os

let queasyAppGroupID = "group.com.jackwallner.queasy"

@MainActor
enum DataService {
    static let appGroupID = queasyAppGroupID

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([ReliefEpisode.self])
        let url = containerURL

        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // A failed migration or half-written file can leave the store unopenable.
        // Episodes exist nowhere else, so move the files aside instead of deleting
        // them; a later build or a support request can still recover the history.
        logger.error("ModelContainer failed to open; quarantining the store and retrying")
        quarantineStore(at: url)
        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // Last-resort in-memory fallback so the app still launches
        let inMemory = ModelConfiguration("Queasy", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            logger.critical("ModelContainer failed even in-memory: \(String(describing: error), privacy: .public)")
            return try! ModelContainer(for: schema, configurations: [inMemory])
        }
    }()

    private static let logger = Logger(subsystem: "com.jackwallner.queasy", category: "DataService")

    /// Renames the store and its SQLite sidecars to `<name>.corrupt-<uuid>` so a
    /// fresh store can open at `url`. Returns the quarantined copies.
    @discardableResult
    nonisolated static func quarantineStore(at url: URL, fileManager: FileManager = .default) -> [URL] {
        let suffix = ".corrupt-\(UUID().uuidString)"
        let candidates = [
            url,
            URL(fileURLWithPath: url.path + "-wal"),
            URL(fileURLWithPath: url.path + "-shm"),
            url.appendingPathExtension("wal"),
            url.appendingPathExtension("shm")
        ]
        var moved: [URL] = []
        for file in candidates where fileManager.fileExists(atPath: file.path) {
            let destination = URL(fileURLWithPath: file.path + suffix)
            if (try? fileManager.moveItem(at: file, to: destination)) != nil {
                moved.append(destination)
            }
        }
        return moved
    }

    private static func makeContainer(schema: Schema, url: URL) -> ModelContainer? {
        let config = ModelConfiguration(
            "Queasy",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    private static var containerURL: URL {
        let base = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Queasy.store")
    }
}
