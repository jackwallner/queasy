import SwiftUI

/// Pane frames for the unfolded iPhone Duo: Relieve and its tabs on the
/// leading side of the fold, History on the trailing side, so no card
/// straddles the crease. `nil` keeps the single phone column (every ordinary
/// iPhone, the folded Duo, and any width too narrow for two panes).
struct UnfoldedSplit: Equatable, Sendable {
    var primaryWidth: CGFloat
    var secondaryX: CGFloat
    var secondaryWidth: CGFloat

    /// Narrowest pane that still fits the phone layout of Relieve and History.
    static let minimumPaneWidth: CGFloat = 360

    /// - Parameters:
    ///   - width: the container's width.
    ///   - fold: the vertical fold's leading and trailing edge in the same
    ///     coordinate space, or `nil` when the system reports none.
    static func make(width: CGFloat, isRegularWidth: Bool, fold: ClosedRange<CGFloat>?) -> UnfoldedSplit? {
        guard isRegularWidth, width >= minimumPaneWidth * 2 else { return nil }
        if let fold,
           fold.lowerBound >= minimumPaneWidth,
           width - fold.upperBound >= minimumPaneWidth {
            return UnfoldedSplit(
                primaryWidth: fold.lowerBound,
                secondaryX: fold.upperBound,
                secondaryWidth: width - fold.upperBound
            )
        }
        let half = (width / 2).rounded(.down)
        return UnfoldedSplit(primaryWidth: half, secondaryX: half, secondaryWidth: width - half)
    }

    static func make(_ geometry: PaneGeometry, isRegularWidth: Bool) -> UnfoldedSplit? {
        make(width: geometry.width, isRegularWidth: isRegularWidth, fold: geometry.fold)
    }
}

/// A container's width and its vertical fold, measured together.
struct PaneGeometry: Equatable, Sendable {
    var width: CGFloat = 0
    var fold: ClosedRange<CGFloat>?
}

extension GeometryProxy {
    var paneGeometry: PaneGeometry {
        PaneGeometry(width: size.width, fold: verticalFold())
    }

    /// The vertical fold's horizontal extent in this proxy's space. Inactive
    /// folds count too, so the panes don't jump while the device opens.
    func verticalFold() -> ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        let fold = reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < size.width }
        guard let fold else { return nil }
        return fold.minX...fold.maxX
    }
}

/// One view tree for both poses: `primary` always fills the leading pane (or
/// the whole width), `secondary` appears beside it only when unfolded. Folding
/// just moves frames, so the primary screen keeps its scroll, navigation and
/// presentations. `primary` gets the split, so a tab whose screen now sits in
/// the secondary pane can drop out of its tab bar.
struct UnfoldedSplitView<Primary: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var geometry = PaneGeometry()
    @ViewBuilder var primary: (_ split: UnfoldedSplit?) -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        let split = UnfoldedSplit.make(geometry, isRegularWidth: horizontalSizeClass == .regular)
        ZStack(alignment: .topLeading) {
            // Each pane is phone-width, so its screen lays out as on a phone.
            primary(split)
                .environment(\.horizontalSizeClass, split == nil ? horizontalSizeClass : .compact)
                .environment(\.isUnfoldedPane, split != nil)
                .frame(maxWidth: split?.primaryWidth ?? .infinity, maxHeight: .infinity)

            if let split {
                secondary()
                    .environment(\.horizontalSizeClass, .compact)
                    .environment(\.isUnfoldedPane, true)
                    .frame(maxWidth: split.secondaryWidth, maxHeight: .infinity)
                    .padding(.leading, split.secondaryX)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onGeometryChange(for: PaneGeometry.self) { $0.paneGeometry } action: { geometry = $0 }
    }
}

extension View {
    /// Keeps a one-column screen (onboarding, the full-screen paywall) in the
    /// leading pane when unfolded, instead of across the fold. Apply it before
    /// the screen's background so the wash still fills the display.
    func leadingPaneColumn() -> some View {
        UnfoldedSplitView { _ in self } secondary: { EmptyView() }
    }
}

extension EnvironmentValues {
    /// True inside a pane of the unfolded split, where `horizontalSizeClass`
    /// has been narrowed to compact and no longer says the display is wide.
    @Entry var isUnfoldedPane = false

    /// Closes a screen that a pane shows in place of a presentation (the
    /// paywall, a session). `nil` when the screen was presented: use `dismiss`.
    @Entry var closePane: ClosePaneAction? = nil
}

/// The close action a pane hands the screen it shows. Equal by `id`, so the
/// environment value doesn't invalidate its readers on every update.
struct ClosePaneAction: Equatable {
    let id: String
    let action: @MainActor () -> Void

    @MainActor func callAsFunction() { action() }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

extension View {
    /// The paywall: a sheet on a phone. Unfolded, it opens in the pane after
    /// the fold (over History, or over the mode it was asked for from), so
    /// Relieve and the tab bar stay put before the fold.
    func paywallSheet(
        isPresented: Binding<Bool>,
        impressionId: String,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(PaywallSheet(isPresented: isPresented, impressionId: impressionId, onDismiss: onDismiss))
    }
}

private struct PaywallSheet: ViewModifier {
    @Binding var isPresented: Bool
    var impressionId: String
    var onDismiss: (() -> Void)?
    @State private var panel = ReliefPanel.shared
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: sheetPresented, onDismiss: onDismiss) {
                PaywallView(displayCloseButton: true, paywallImpressionId: impressionId)
            }
            .onChange(of: isPresented && panel.opensInPane, initial: true) { _, inPane in
                if inPane {
                    panel.paywall = .init(token: token, impressionId: impressionId)
                } else if panel.paywall?.token == token {
                    panel.paywall = nil
                }
            }
            // The pane's close button, or a mode opened over it.
            .onChange(of: panel.paywall) { old, new in
                guard old?.token == token, new?.token != token, panel.opensInPane, isPresented else { return }
                isPresented = false
                onDismiss?()
            }
    }

    private var sheetPresented: Binding<Bool> {
        Binding(
            get: { isPresented && !panel.opensInPane },
            set: { if !$0, !panel.opensInPane { isPresented = false } }
        )
    }
}

extension View {
    /// Lays out as is when it fits, and scrolls when it doesn't. Both Duo
    /// displays are 669 to 678 pt tall, so tall screens scroll there instead
    /// of truncating.
    func scrollsWhenTall() -> some View {
        ViewThatFits(in: .vertical) {
            self
            ScrollView { self }
                .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The trailing pane keeps the phone's horizontal bars. iOS 27.1
    /// otherwise moves its toolbar, with the status bar, into a column on the
    /// inner display's trailing edge, which left History's share button
    /// outside its pane and History narrower than Relieve. Only the split's
    /// trailing pane uses it: nothing else changes the system default.
    @ViewBuilder
    func horizontalBarsInPane() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }

    /// Hides the iOS 26 top scroll edge effect, whose material tinted the
    /// navigation bar over the in-pane session.
    @ViewBuilder
    func topScrollEdgeEffectHidden(_ hidden: Bool) -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(hidden, for: .top)
        } else {
            self
        }
    }

    /// One tab's root. Unfolded, the leading pane hides the system tab bar (a
    /// glass capsule floating over the pane's last rows); its tabs move to the
    /// title's place instead (`paneNavigationTitle`). The preference comes
    /// from a background layer, so only that layer is rebuilt on fold.
    func paneTab(_ hidesBar: Bool) -> some View {
        background {
            if hidesBar {
                Color.clear.toolbar(.hidden, for: .tabBar)
            }
        }
    }

    /// `tideNavigationTitle`, except in the unfolded leading pane, where the
    /// tabs take the title's place, level with History's title across the
    /// fold. The title there only repeated the selected tab.
    func paneNavigationTitle(_ title: String) -> some View {
        modifier(PaneNavigationTitle(title: title))
    }
}

/// The leading pane's tabs while History has a pane of its own.
struct PaneTabs {
    struct Item: Identifiable {
        let tag: Int
        let title: String
        let systemImage: String
        var id: Int { tag }
    }

    var selection: Binding<Int>
    var items: [Item]
}

extension EnvironmentValues {
    /// Set on the leading pane's tabs while split; `nil` everywhere else.
    @Entry var paneTabs: PaneTabs? = nil
}

private struct PaneNavigationTitle: ViewModifier {
    @Environment(\.paneTabs) private var tabs
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .principal) { principal }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .principal) { principal }
                }
            }
    }

    /// One item whose content switches, so folding never rebuilds the tab.
    @ViewBuilder
    private var principal: some View {
        if let tabs {
            PaneTabStrip(tabs: tabs)
        } else {
            Text(title)
                .font(Theme.displaySerif(20))
                .foregroundStyle(Theme.ink)
        }
    }
}

/// The tabs as one capsule in the leading pane's navigation bar.
struct PaneTabStrip: View {
    let tabs: PaneTabs

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs.items) { item in
                button(item)
            }
        }
        .padding(3)
        .background(Theme.paper2.opacity(0.6), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func button(_ item: PaneTabs.Item) -> some View {
        let isSelected = tabs.selection.wrappedValue == item.tag
        return Button {
            tabs.selection.wrappedValue = item.tag
        } label: {
            Label(item.title, systemImage: item.systemImage)
                .labelStyle(.titleAndIcon)
                .symbolVariant(.fill)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isSelected ? Theme.aqua : Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(isSelected ? Theme.aquaTint : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
