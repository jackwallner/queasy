import SwiftUI

struct RootTabView: View {
    @State private var reviewCoordinator = ReviewPromptCoordinator.shared
    @State private var upgradeCoordinator = UpgradePromptCoordinator.shared
    @State private var showReview = false
    @State private var showUpgrade = false
    @State private var upgradeImpressionId = "queasy_after_session"
    @State private var reviewStep: ReviewPromptSheet.Step = .enjoyment
    @State private var tab = Self.initialTab

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

    var body: some View {
        TabView(selection: $tab) {
            RelieveHomeView()
                .tabItem { Label("Relieve", systemImage: "dot.radiowaves.left.and.right") }
                .tag(0)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)
            LearnView()
                .tabItem { Label("Learn", systemImage: "book") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(Theme.aqua)
        // The rating screen that triggers this is a full-screen cover being
        // dismissed at the same moment; wait a beat so the sheet presents onto a
        // clear tab view instead of racing the cover's dismissal.
        .onChange(of: reviewCoordinator.pendingStep) { _, step in
            guard let step else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                reviewStep = step
                showReview = true
            }
        }
        .sheet(isPresented: $showReview, onDismiss: { reviewCoordinator.clear() }) {
            ReviewPromptSheet(initialStep: reviewStep)
        }
        // Same staging problem as the review sheet: the session cover is on its
        // way out when this is requested.
        .onChange(of: upgradeCoordinator.pendingImpressionId) { _, id in
            guard let id else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                upgradeImpressionId = id
                showUpgrade = true
            }
        }
        .sheet(isPresented: $showUpgrade, onDismiss: { upgradeCoordinator.clear() }) {
            PaywallView(displayCloseButton: true, paywallImpressionId: upgradeImpressionId)
        }
    }
}
