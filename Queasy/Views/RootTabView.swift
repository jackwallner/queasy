import StoreKit
import SwiftUI
import UIKit

struct RootTabView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.requestReview) private var requestReview
    @State private var reviewCoordinator = ReviewPromptCoordinator.shared
    @State private var upgradeCoordinator = UpgradePromptCoordinator.shared
    @State private var showUpgrade = false
    @State private var upgradeImpressionId = "queasy_after_session"
    @State private var reviewTask: Task<Void, Never>?
    @State private var tab = Self.initialTab
    #if DEBUG
    @State private var duoTour = DuoTour.shared
    #endif

    /// `-QueasyTab history|learn|settings` opens straight onto a tab, so a
    /// headless simulator (which can be launched but not tapped) can still be
    /// used to review every screen.
    private static var initialTab: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-QueasyTab"), args.indices.contains(flag + 1) else { return 0 }
        switch args[flag + 1] {
        case "history": return 1
        case "learn": return 2
        case "settings": return 3
        default: return 0
        }
        #else
        return 0
        #endif
    }

    /// Folded, four tabs. Unfolded, the tabs and their bar take the pane before
    /// the fold and History the pane after it, so what you try now sits beside
    /// what helped before. The History tab drops out of the bar while split.
    var body: some View {
        UnfoldedSplitView { isSplit in
            TabView(selection: $tab) {
                RelieveHomeView()
                    .tabItem { Label("Relieve", systemImage: "dot.radiowaves.left.and.right") }
                    .tag(0)
                if !isSplit {
                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                        .tag(1)
                }
                LearnView()
                    .tabItem { Label("Learn", systemImage: "book") }
                    .tag(2)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(3)
            }
            .onChange(of: isSplit, initial: true) { _, isSplit in
                ReliefPanel.shared.opensInPane = isSplit
                if isSplit, tab == 1 { tab = 0 }
            }
            .foldAwareSheet(isPresented: $showUpgrade, onDismiss: { upgradeCoordinator.clear() }) {
                PaywallView(displayCloseButton: true, paywallImpressionId: upgradeImpressionId)
            }
        } secondary: {
            // A mode or the check-in opens here, beside the grid it came from,
            // over History, which stays mounted underneath.
            ZStack {
                HistoryView()
                if let item = ReliefPanel.shared.item {
                    ReliefPanelScreen(item: item)
                        .id(item)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: ReliefPanel.shared.item)
        }
        .tideBackground()
        .tint(Theme.aqua)
        #if DEBUG
        .onChange(of: duoTour.scene) { _, scene in
            tab = DuoTour.tab(for: scene)
            showUpgrade = false
            if scene == "upgrade" { upgradeCoordinator.request("queasy_duo_tour") }
        }
        #endif
        .onChange(of: reviewCoordinator.momentCount) { _, _ in
            scheduleReviewRequestAfterPositiveMoment()
        }
        // The session cover is on its way out when this is requested; wait a
        // beat so the sheet presents onto a clear tab view.
        .onChange(of: upgradeCoordinator.pendingImpressionId) { _, id in
            guard let id else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                upgradeImpressionId = id
                showUpgrade = true
            }
        }
    }

    /// The rating ask after a finished session: Apple's own prompt, no question
    /// in front of it. Waits for the session cover to close, then asks only if
    /// nothing is presented. A blocked ask keeps the moment pending.
    private func scheduleReviewRequestAfterPositiveMoment() {
        reviewTask?.cancel()
        reviewTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, isClear,
                  ReviewPromptTracker.shouldRequestAfterPositiveMoment(hasCompletedSetup: settings.hasCompletedOnboarding)
            else { return }
            ReviewPromptTracker.markShown()
            requestReview()
        }
    }

    /// No paywall, cover, sheet or alert is up over the tabs.
    private var isClear: Bool {
        guard !showUpgrade, upgradeCoordinator.pendingImpressionId == nil,
              UIApplication.shared.applicationState == .active
        else { return false }
        return !UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains { $0.isKeyWindow && $0.rootViewController?.presentedViewController != nil }
    }
}

/// Signals a positive moment from inside a session cover so `RootTabView`
/// can ask for a rating once the cover is gone.
@MainActor
@Observable
final class ReviewPromptCoordinator {
    static let shared = ReviewPromptCoordinator()
    private init() {}

    private(set) var momentCount = 0

    func recordPositiveMoment() {
        guard !ReviewPromptTracker.skipsAutomation else { return }
        ReviewPromptTracker.recordPositiveMoment()
        momentCount += 1
    }
}
