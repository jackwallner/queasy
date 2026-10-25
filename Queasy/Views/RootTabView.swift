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
    @State private var panel = ReliefPanel.shared
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

    /// Folded, four tabs. Unfolded, the tabs take the pane before the fold,
    /// switched from its navigation bar, and History the pane after it, so
    /// what you try now sits beside what helped before. History drops out of
    /// the tabs while split.
    var body: some View {
        UnfoldedSplitView { split in
            TabView(selection: $tab) {
                // A session is full screen on a phone, but the Duo's outer
                // display kept its vertical tab bar beside the cover.
                RelieveHomeView()
                    .paneTab(split != nil || panel.sessionIsUp)
                    .tabItem { Label("Relieve", systemImage: "dot.radiowaves.left.and.right") }
                    .tag(0)
                if split == nil {
                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                        .tag(1)
                }
                LearnView()
                    .paneTab(split != nil)
                    .tabItem { Label("Learn", systemImage: "book") }
                    .tag(2)
                SettingsView()
                    .paneTab(split != nil)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(3)
            }
            .environment(\.paneTabs, split == nil ? nil : PaneTabs(selection: $tab, items: Self.paneTabItems))
            .onChange(of: split != nil, initial: true) { _, isSplit in
                panel.opensInPane = isSplit
                if isSplit, tab == 1 { tab = 0 }
            }
            .paywallSheet(isPresented: $showUpgrade, impressionId: upgradeImpressionId) {
                upgradeCoordinator.clear()
            }
        } secondary: {
            // A mode, the check-in or the paywall opens here, beside the grid
            // it came from, over History, which stays mounted underneath.
            ZStack {
                HistoryView()
                if let item = panel.item {
                    ReliefPanelScreen(item: item)
                        .id(item)
                        .transition(.opacity)
                }
                if let paywall = panel.paywall {
                    PaywallView(displayCloseButton: true, paywallImpressionId: paywall.impressionId)
                        .environment(\.closePane, ClosePaneAction(id: "paywall") { panel.paywall = nil })
                        .id(paywall.token)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: panel.item)
            .animation(.easeInOut(duration: 0.25), value: panel.paywall)
            .horizontalBarsInPane()
        }
        .tideBackground()
        .tint(Theme.aqua)
        #if DEBUG
        // `-QueasyScreen upgrade`: the after-session paywall, for captures.
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard let flag = args.firstIndex(of: "-QueasyScreen"), args.indices.contains(flag + 1),
                  args[flag + 1] == "upgrade" else { return }
            try? await Task.sleep(for: .milliseconds(400))
            upgradeCoordinator.request("queasy_screenshot")
        }
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

    /// The tabs left in the leading pane while History has its own.
    private static let paneTabItems: [PaneTabs.Item] = [
        .init(tag: 0, title: "Relieve", systemImage: "dot.radiowaves.left.and.right"),
        .init(tag: 2, title: "Learn", systemImage: "book"),
        .init(tag: 3, title: "Settings", systemImage: "gearshape"),
    ]

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
