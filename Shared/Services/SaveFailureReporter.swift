import Foundation
import Observation
import SwiftData
import os

/// Surfaces a local save that did not land. Without it a failed write looks
/// exactly like a successful one, and the episode is gone on the next launch.
@MainActor
@Observable
final class SaveFailureReporter {
    static let shared = SaveFailureReporter()

    /// The last write that failed, phrased for a person. Nil while the store is fine.
    var message: String?

    private let logger = Logger(subsystem: "com.jackwallner.queasy", category: "DataService")

    private init() {}

    func report(_ error: Error) {
        logger.error("Local save failed: \(String(describing: error), privacy: .private)")
        message = "Your last change could not be saved on this iPhone, so it may be missing after you close Queasy. This is usually because storage is full. Free up some space and try again."
    }
}

extension ModelContext {
    /// Saves, or rolls back and reports so the screen never shows a change the
    /// store rejected.
    @MainActor
    @discardableResult
    func saveOrReport() -> Bool {
        do {
            try save()
            return true
        } catch {
            rollback()
            SaveFailureReporter.shared.report(error)
            return false
        }
    }
}
