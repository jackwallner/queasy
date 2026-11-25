import Foundation
import Testing
@testable import Queasy

/// The rating-ask rules from the fleet policy: ask from the second launch,
/// wait out a 30-day cooldown, stop only when the user opened the review page,
/// and never let feedback stop or restart the asks.
@Suite("Review prompt tracker", .serialized)
struct ReviewPromptTrackerTests {
    /// Snapshots and restores the tracker's persisted state so the suite
    /// doesn't leave a simulator install mid-ask.
    private func withCleanTracker(_ body: () -> Void) {
        let launches = ReviewPromptTracker.appLaunchCount
        let lastShown = ReviewPromptTracker.lastShownDate
        let outcome = ReviewPromptTracker.outcome
        let pending = ReviewPromptTracker.hasPendingPositiveMoment
        defer {
            ReviewPromptTracker.appLaunchCount = launches
            ReviewPromptTracker.lastShownDate = lastShown
            ReviewPromptTracker.outcome = outcome
            ReviewPromptTracker.hasPendingPositiveMoment = pending
        }
        ReviewPromptTracker.outcome = nil
        ReviewPromptTracker.lastShownDate = nil
        ReviewPromptTracker.hasPendingPositiveMoment = false
        body()
    }

    @Test func asksFromTheSecondSession() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 2
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func neverAsksInTheFirstSession() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 1
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func stillRequiresFinishedOnboarding() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: false))
        }
    }

    @Test func openingTheReviewPageEndsTheAsks() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.markOpenedWriteReview()
            ReviewPromptTracker.lastShownDate = Date.now.addingTimeInterval(-365 * 86_400)
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func waitsOutTheCooldown() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.lastShownDate = Date.now.addingTimeInterval(-10 * 86_400)
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
            ReviewPromptTracker.lastShownDate = Date.now.addingTimeInterval(-31 * 86_400)
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func feedbackNeverEndsTheAsks() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.markFeedbackSubmitted()
            #expect(ReviewPromptTracker.outcome == .submittedFeedback)
            #expect(ReviewPromptTracker.lastShownDate == nil, "feedback must not start a cooldown")
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    @Test func feedbackAfterTheReviewPageKeepsTheAsksEnded() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.markOpenedWriteReview()
            ReviewPromptTracker.markFeedbackSubmitted()
            #expect(ReviewPromptTracker.outcome == .openedWriteReview)
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }

    /// A moment whose ask finds something presented must survive that skip so
    /// the next finished session can still ask.
    @Test func blockedAskKeepsTheMomentPending() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.recordPositiveMoment()
            #expect(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            #expect(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            ReviewPromptTracker.markShown()
            #expect(!ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        }
    }

    /// The good moment is a session the user rated as helping. A neutral, bad
    /// or skipped rating never asks.
    @Test func anySessionNotRatedWorseIsAGoodMoment() {
        #expect(ReviewPromptTracker.isPositiveMoment(feeling: .better))
        #expect(ReviewPromptTracker.isPositiveMoment(feeling: .same))
        #expect(ReviewPromptTracker.isPositiveMoment(feeling: nil))
        #expect(!ReviewPromptTracker.isPositiveMoment(feeling: .worse))
    }

    @Test func firstLaunchMomentIsBlockedAndSecondLaunchMomentAsks() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 1
            ReviewPromptTracker.recordPositiveMoment()
            #expect(!ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
            ReviewPromptTracker.appLaunchCount = 2
            #expect(ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        }
    }

    @Test func noMomentMeansNoAsk() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            #expect(!ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: true))
        }
    }

    /// The cooldown starts when the call is made, measured from that stamp.
    @Test func markShownStartsTheCooldown() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            let asked = Date.now
            ReviewPromptTracker.markShown(now: asked)
            #expect(!ReviewPromptTracker.canRequestReview(hasCompletedSetup: true, now: asked.addingTimeInterval(29 * 86_400)))
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true, now: asked.addingTimeInterval(30 * 86_400)))
        }
    }

    /// A stamp from a clock that ran ahead must not hold the asks shut.
    @Test func aFutureStampDoesNotHoldTheCooldownShut() {
        withCleanTracker {
            ReviewPromptTracker.appLaunchCount = 9
            ReviewPromptTracker.lastShownDate = Date.now.addingTimeInterval(200 * 86_400)
            #expect(ReviewPromptTracker.canRequestReview(hasCompletedSetup: true))
        }
    }
}
