import SwiftUI

/// Where Relieve opens a mode's detail and the check-in: a sheet on a phone,
/// and on the unfolded iPhone Duo the pane after the fold, beside the mode
/// grid it was picked from (a centred sheet would sit across the fold).
@MainActor
@Observable
final class ReliefPanel {
    static let shared = ReliefPanel()
    private init() {}

    enum Item: Hashable, Identifiable {
        case mode(ReliefMode)
        case checkIn

        var id: Self { self }
    }

    /// A paywall asked for while split. It opens over the panel, so closing
    /// it returns to the mode or check-in it was opened from.
    struct Paywall: Equatable {
        let token: UUID
        let impressionId: String
    }

    var item: Item?
    var paywall: Paywall?
    /// Set by `RootTabView` while the display is split.
    var opensInPane = false
    /// Set by `RelieveHomeView` while a session is up, as a cover or in the
    /// pane; `RootTabView` hides the tab bar then.
    var sessionIsUp = false

    func open(_ item: Item) {
        paywall = nil
        self.item = item
    }

    func close() { item = nil }
}

/// The screen for a `ReliefPanel.Item`, the same in a sheet or a pane.
struct ReliefPanelScreen: View {
    let item: ReliefPanel.Item

    var body: some View {
        switch item {
        case .mode(let mode):
            ModeStartView(mode: mode) { AppSettings.shared.lastPlan = $0 }
        case .checkIn:
            CheckInView { AppSettings.shared.lastPlan = $0 }
        }
    }
}
