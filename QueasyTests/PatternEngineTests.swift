import Foundation
import Testing
@testable import Queasy

struct PatternEngineTests {
    private func checkIn(
        cause: NauseaCause = .motion,
        severity: Int,
        stillExposed: Bool = false,
        recentlyAte: Bool = false
    ) -> CheckIn {
        CheckIn(cause: cause, severity: severity, stillExposed: stillExposed, recentlyAte: recentlyAte)
    }

    @Test func intensityScalesWithSeverity() {
        var previous = 0
        for severity in 1...5 {
            let plan = PatternEngine.recommend(for: checkIn(severity: severity))
            #expect(plan.intensity >= previous)
            previous = plan.intensity
        }
        #expect(PatternEngine.recommend(for: checkIn(severity: 1)).intensity == 2)
        #expect(PatternEngine.recommend(for: checkIn(severity: 5)).intensity == 10)
    }

    @Test func stillExposedAddsOneLevel() {
        let calm = PatternEngine.recommend(for: checkIn(severity: 3))
        let exposed = PatternEngine.recommend(for: checkIn(severity: 3, stillExposed: true))
        #expect(exposed.intensity == calm.intensity + 1)
    }

    @Test func worstCaseClampsToMaxIntensity() {
        let plan = PatternEngine.recommend(for: checkIn(cause: .hangover, severity: 5, stillExposed: true))
        #expect(plan.intensity == PatternEngine.maxIntensity)
    }

    @Test func recentMealSoftensStart() {
        let empty = PatternEngine.recommend(for: checkIn(severity: 3))
        let full = PatternEngine.recommend(for: checkIn(severity: 3, recentlyAte: true))
        #expect(full.intensity == empty.intensity - 1)
    }

    @Test func intensityStaysInBounds() {
        for severity in [-3, 0, 1, 5, 9] {
            for exposed in [true, false] {
                for ate in [true, false] {
                    for cause in NauseaCause.allCases {
                        let plan = PatternEngine.recommend(
                            for: checkIn(cause: cause, severity: severity, stillExposed: exposed, recentlyAte: ate)
                        )
                        #expect(plan.intensity >= PatternEngine.minIntensity)
                        #expect(plan.intensity <= PatternEngine.maxIntensity)
                        #expect(plan.durationMinutes >= PatternEngine.minDuration)
                        #expect(plan.durationMinutes <= PatternEngine.maxDuration)
                    }
                }
            }
        }
    }

    @Test func hangoverRunsLonger() {
        let base = PatternEngine.recommend(for: checkIn(cause: .motion, severity: 3)).durationMinutes
        let hangover = PatternEngine.recommend(for: checkIn(cause: .hangover, severity: 3)).durationMinutes
        #expect(hangover == base + 5)
    }

    @Test func everyCauseHasTips() {
        for cause in NauseaCause.allCases {
            let plan = PatternEngine.recommend(for: checkIn(cause: cause, severity: 3))
            #expect(!plan.tips.isEmpty)
        }
    }

    @Test func pulseTableHasTenMonotonicLevels() {
        #expect(PulseSpec.levels.count == 10)
        for pair in zip(PulseSpec.levels, PulseSpec.levels.dropFirst()) {
            #expect(pair.0.interval >= pair.1.interval)
            #expect(pair.0.burstCount <= pair.1.burstCount)
        }
    }

    @Test func specLevelClamps() {
        #expect(PulseSpec.forLevel(0) == PulseSpec.levels[0])
        #expect(PulseSpec.forLevel(99) == PulseSpec.levels[9])
        #expect(PulseSpec.forLevel(4) == PulseSpec.levels[3])
    }

    @Test func planRoundTripsThroughJSON() throws {
        let plan = PatternEngine.recommend(for: checkIn(cause: .vertigo, severity: 4, stillExposed: true))
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(ReliefPlan.self, from: data)
        #expect(decoded == plan)
    }
}
