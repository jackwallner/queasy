import CoreGraphics
import Testing
@testable import Queasy

struct UnfoldedSplitTests {
    /// The unfolded iPhone Duo inner display in landscape, with its fold.
    private let innerWidth: CGFloat = 951
    private let fold: ClosedRange<CGFloat> = 455.5...495.5

    @Test func compactWidthKeepsOneColumn() {
        #expect(UnfoldedSplit.make(width: 466, isRegularWidth: false, fold: nil) == nil)
        #expect(UnfoldedSplit.make(width: innerWidth, isRegularWidth: false, fold: fold) == nil)
    }

    @Test func portraitUnfoldedIsTooNarrowForTwoPanes() {
        #expect(UnfoldedSplit.make(width: 669, isRegularWidth: true, fold: nil) == nil)
    }

    @Test func panesMeetTheFoldEdges() throws {
        let split = try #require(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: fold))
        #expect(split.primaryWidth == 455.5)
        #expect(split.secondaryX == 495.5)
        #expect(split.secondaryWidth == innerWidth - 495.5)
    }

    @Test func noFoldSplitsEvenly() throws {
        let split = try #require(UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: nil))
        #expect(split.primaryWidth == 475)
        #expect(split.secondaryX == 475)
        #expect(split.secondaryWidth == 476)
    }

    @Test func offCentreFoldThatStarvesAPaneFallsBackToEvenSplit() throws {
        let split = try #require(UnfoldedSplit.make(width: 800, isRegularWidth: true, fold: 300...320))
        #expect(split.primaryWidth == 400)
        #expect(split.secondaryX == 400)
    }

    @Test func zeroWidthFoldSharesOneEdge() throws {
        let split = try #require(UnfoldedSplit.make(width: 800, isRegularWidth: true, fold: 400...400))
        #expect(split.primaryWidth == 400)
        #expect(split.secondaryX == 400)
        #expect(split.secondaryWidth == 400)
    }

    @Test func exactlyTwoMinimumPanesStillSplits() {
        let width = UnfoldedSplit.minimumPaneWidth * 2
        #expect(UnfoldedSplit.make(width: width, isRegularWidth: true, fold: nil) != nil)
        #expect(UnfoldedSplit.make(width: width - 1, isRegularWidth: true, fold: nil) == nil)
    }

    @Test func geometryWrapperMatchesTheRawInputs() {
        let geometry = PaneGeometry(width: innerWidth, fold: fold)
        #expect(UnfoldedSplit.make(geometry, isRegularWidth: true)
            == UnfoldedSplit.make(width: innerWidth, isRegularWidth: true, fold: fold))
    }

    @Test func tourScenesMapToTheirTabs() {
        #expect(DuoTour.tab(for: "learn") == 2)
        #expect(DuoTour.tab(for: "settings") == 3)
        #expect(DuoTour.tab(for: "relieve") == 0)
        #expect(DuoTour.tab(for: nil) == 0)
    }

    @MainActor @Test func reliefPanelOpensAndCloses() {
        let panel = ReliefPanel.shared
        panel.open(.mode(.breathe))
        #expect(panel.item == .mode(.breathe))
        panel.close()
        #expect(panel.item == nil)
    }
}
