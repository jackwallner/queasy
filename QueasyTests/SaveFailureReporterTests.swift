import Foundation
import SwiftData
import Testing
@testable import Queasy

@MainActor
@Suite(.serialized)
struct SaveFailureReporterTests {
    @Test func successfulSaveReportsNothing() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ReliefEpisode.self, configurations: config)
        let context = container.mainContext
        SaveFailureReporter.shared.message = nil

        context.insert(ReliefEpisode(
            startedAt: .now, endedAt: .now, cause: .motion,
            severityBefore: 3, severityAfter: 1, intensity: 5,
            plannedMinutes: 5, source: .phone
        ))

        #expect(context.saveOrReport())
        #expect(SaveFailureReporter.shared.message == nil)
        #expect(try context.fetchCount(FetchDescriptor<ReliefEpisode>()) == 1)
    }

    @Test func reportedFailureProducesPlainMessage() {
        SaveFailureReporter.shared.message = nil
        SaveFailureReporter.shared.report(CocoaError(.fileWriteOutOfSpace))
        let message = try? #require(SaveFailureReporter.shared.message)
        #expect(message?.contains("could not be saved") == true)
        #expect(message?.contains("—") == false)
        SaveFailureReporter.shared.message = nil
    }
}
