import Foundation
import Testing
@testable import Queasy

/// Ask to Buy reads as waiting for approval, never as a failed purchase, and a
/// lost connection reads as the app's own translated line, not RevenueCat's
/// English description. `Queasy.` is the app's copy, built with RevenueCat.
@MainActor
struct PurchaseFailureTests {
    @Test func askToBuyIsWaitingForApproval() {
        #expect(Queasy.PurchaseFailure.fromSDK(.paymentPending) == .waitingForApproval)
        #expect(Queasy.PurchaseFailure.fromSDK(.paymentPending, asNSError: true) == .waitingForApproval)
    }

    @Test func aLostConnectionReadsAsTheConnectionLine() {
        for sdkCase in [Queasy.PurchaseFailure.SDKCase.network, .offline] {
            #expect(Queasy.PurchaseFailure.fromSDK(sdkCase) == .storeUnreachable)
            #expect(Queasy.PurchaseFailure.fromSDK(sdkCase, asNSError: true) == .storeUnreachable)
        }
    }

    @Test func otherErrorsKeepTheFailedLine() {
        #expect(Queasy.PurchaseFailure.fromSDK(.purchaseNotAllowed) == .failed)
        #expect(Queasy.PurchaseFailure.fromSDK(.storeProblem, asNSError: true) == .failed)
        #expect(Queasy.PurchaseFailure(URLError(.badServerResponse)) == .failed)
    }

    @Test func pendingCopyIsCalmAndTheOthersAreUnchanged() {
        #expect(Queasy.PurchaseFailure.waitingForApproval.message == "Waiting for approval. Your purchase unlocks once it is approved.")
        #expect(Queasy.PurchaseFailure.storeUnreachable.message == "Check your connection and try again.")
        #expect(Queasy.PurchaseFailure.failed.message == "Purchase didn't complete. Please try again.")
    }

    @Test func analyticsLogsPendingApartFromError() {
        #expect(Queasy.PurchaseFailure.waitingForApproval.analyticsOutcome == "pending")
        #expect(Queasy.PurchaseFailure.storeUnreachable.analyticsOutcome == "error")
        #expect(Queasy.PurchaseFailure.failed.analyticsOutcome == "error")
    }
}
