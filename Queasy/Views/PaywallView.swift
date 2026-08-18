import SwiftUI
#if HAS_REVENUECAT
import RevenueCat
#endif

/// Apple-required legal links on the paywall (3.1.2).
enum PaywallLinks {
    static let privacyPolicy = URL(string: "https://jackwallner.github.io/queasy/privacy-policy.html")!
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// The only support contact, surfaced in Settings and on the support page.
    static let support = URL(string: "mailto:jackwallner+q@gmail.com")!
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptions = SubscriptionService.shared

    var displayCloseButton: Bool = true
    var paywallImpressionId: String = "queasy_sheet"

    #if HAS_REVENUECAT
    @State private var selectedPackage: Package?
    #endif
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?

    #if DEBUG
    /// Simulator screenshot harness: `-QueasyPaywallScreenshot` renders the
    /// paywall with static plan cards (RC products don't load on a bare sim).
    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-QueasyPaywallScreenshot")
    }
    #else
    private var isScreenshotMode: Bool { false }
    #endif

    var body: some View {
        ZStack(alignment: .top) {
            Theme.paper.ignoresSafeArea()

            #if HAS_REVENUECAT
            if isScreenshotMode {
                mockPaywallContent
            } else if subscriptions.isLoadingProducts && subscriptions.products.isEmpty {
                loadingState
            } else if subscriptions.products.isEmpty {
                emptyState
            } else {
                paywallContent
            }
            #else
            offlinePlaceholder
            #endif

            if displayCloseButton {
                closeButton
            }
        }
        .onChange(of: subscriptions.isProSubscriber) { _, isPro in
            if isPro { dismiss() }
        }
        .task {
            #if HAS_REVENUECAT
            subscriptions.trackPaywallImpression(id: paywallImpressionId)
            if subscriptions.products.isEmpty {
                await subscriptions.fetchProducts()
            }
            selectDefaultPackageIfNeeded()
            #else
            AnalyticsService.paywallShown()
            #endif
        }
        #if HAS_REVENUECAT
        .onChange(of: subscriptions.products.count) { _, _ in
            selectDefaultPackageIfNeeded()
        }
        #endif
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().tint(Theme.aqua)
            Text("loading plans…")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink2)
            Spacer()
            legalFooter
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.ink3)
            Text("couldn't load plans")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Theme.ink2)
            Text(subscriptionsLastError)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("try again") {
                Task {
                    #if HAS_REVENUECAT
                    await subscriptions.fetchProducts()
                    selectDefaultPackageIfNeeded()
                    #endif
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.aqua)
            Spacer()
            legalFooter
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
    }

    private var subscriptionsLastError: String {
        #if HAS_REVENUECAT
        return subscriptions.lastError ?? "Check your connection and try again."
        #else
        return "Check your connection and try again."
        #endif
    }

    private var paywallContent: some View {
        VStack(spacing: 10) {
            header
            trustStrip
            if selectedTrialLabel != nil {
                trialTimeline
            } else {
                compactFeatureList
            }
            planCards
            Spacer(minLength: 0)
            purchaseBlock
            legalFooter
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 48 : 20)
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("QUEASY PRO")
                .font(.caption2.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Theme.ink3)
            Text(headlineText)
                .font(Theme.displaySerif(26))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(subtitleText)
                .font(.footnote)
                .foregroundStyle(Theme.ink2)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headlineText: String {
        #if HAS_REVENUECAT
        if let pkg = selectedPackage ?? subscriptions.products.first(where: { $0.queasyPackageKind == .yearly }),
           subscriptions.isEligibleForIntroOffer(pkg),
           let trial = pkg.queasyIntroOfferLabel {
            return "Try Queasy Pro\n\(trial)."
        }
        #endif
        return "Sessions as long as\nyou actually need."
    }

    private var subtitleText: String {
        #if HAS_REVENUECAT
        if let package = selectedPackage,
           package.queasyPackageKind != .lifetime,
           subscriptions.isEligibleForIntroOffer(package) {
            return "Then \(package.queasyPriceLabel), cancel anytime."
        }
        #endif
        return "Free sessions run \(FreeTier.sessionSeconds / 60) minutes. Pro runs up to \(PatternEngine.maxDuration)."
    }

    private var trustStrip: some View {
        HStack(spacing: 14) {
            trustItem(icon: "leaf", label: "Drug-free")
            Divider().frame(height: 14).background(Theme.paper3)
            trustItem(icon: "lock.shield", label: "Private")
            Divider().frame(height: 14).background(Theme.paper3)
            trustItem(icon: "moon.stars", label: "No ads, ever")
        }
        .frame(maxWidth: .infinity)
    }

    private func trustItem(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Theme.aqua)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.ink2)
        }
    }

    /// Trial label ("7-day free trial") for the current selection, nil when
    /// the selection has no intro offer (lifetime, or trial already used).
    private var selectedTrialLabel: String? {
        #if HAS_REVENUECAT
        guard let package = selectedPackage,
              package.queasyPackageKind != .lifetime,
              subscriptions.isEligibleForIntroOffer(package) else { return nil }
        return package.queasyIntroOfferLabel
        #else
        return nil
        #endif
    }

    /// "How your free trial works" — the timeline that actually explains the
    /// deal: everything unlocked today, nothing charged until the trial ends.
    private var trialTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow(
                icon: "lock.open.fill",
                title: "Today",
                text: "Unlock every pattern, both devices, free.",
                showsLine: true
            )
            timelineRow(
                icon: "bell.fill",
                title: "Day 5",
                text: "Check History. How do you feel?",
                showsLine: true
            )
            timelineRow(
                icon: "star.fill",
                title: trialEndTitle,
                text: "First charge, only if you keep it. Cancel before then and pay nothing.",
                showsLine: false
            )
        }
        .padding(14)
        .background(Theme.aquaTint.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trialEndTitle: String {
        #if HAS_REVENUECAT
        if let trial = selectedTrialLabel, trial.lowercased().contains("7") { return "Day 7" }
        #endif
        return "Trial ends"
    }

    private func timelineRow(icon: String, title: String, text: String, showsLine: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Theme.aqua, in: Circle())
                if showsLine {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.aqua.opacity(0.35))
                        .frame(width: 2, height: 14)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, showsLine ? 6 : 0)
            Spacer(minLength: 0)
        }
    }

    private var compactFeatureList: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Driven off ProFeature so the bullets and the gates cannot drift.
            ForEach(ProFeature.allCases) { feature in
                compactBenefit(icon: feature.symbolName, title: feature.title)
            }

            Text("Every mode stays free, unlimited, with no account. Pro buys length, memory and reminders. Queasy is a set of comfort techniques, not a medical device, and it makes no treatment claims.")
                .font(.caption2)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactBenefit(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.aqua)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
    }

    #if HAS_REVENUECAT
    private var planCards: some View {
        VStack(spacing: 10) {
            ForEach(subscriptions.products, id: \.identifier) { package in
                QueasyPlanCard(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier,
                    showsTrialBadge: subscriptions.isEligibleForIntroOffer(package),
                    isBestValue: package.queasyPackageKind == .yearly,
                    savingsPercent: savingsPercent(for: package),
                    perMonthLabel: perMonthLabel(for: package)
                ) {
                    selectedPackage = package
                }
            }
        }
    }
    #else
    private var planCards: some View { EmptyView() }
    #endif

    // MARK: - Purchase

    private var purchaseBlock: some View {
        VStack(spacing: 8) {
            if selectedTrialLabel != nil {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.aqua)
                    Text("No payment due now")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(.white)
                    }
                }
            }
            .buttonStyle(.tideCTA)
            .disabled(isPurchasing || !hasSelection)

            Text(disclosureText ?? " ")
                .font(.caption2)
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.9)
                .frame(minHeight: 44, alignment: .top)
                .opacity(disclosureText == nil ? 0 : 1)
                .accessibilityHidden(disclosureText == nil)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.coral)
                    .multilineTextAlignment(.center)
            }
            if let restoreMessage {
                Text(restoreMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var hasSelection: Bool {
        #if HAS_REVENUECAT
        return selectedPackage != nil
        #else
        return false
        #endif
    }

    /// Restore + legal links. Required by 3.1.2 in EVERY paywall state.
    private var legalFooter: some View {
        HStack(spacing: 14) {
            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink2)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)

            HStack(spacing: 4) {
                Link("Terms of Use", destination: PaywallLinks.standardEULA)
                Text("·")
                Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.ink3)
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 30, height: 30)
                    .background(Theme.paper2, in: Circle())
                    .padding(12)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
    }

    /// Static twin of `paywallContent` for screenshots and IAP review images.
    private var mockPaywallContent: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("QUEASY PRO")
                    .font(.caption2.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.ink3)
                Text("Try Queasy Pro\n7-day free trial.")
                    .font(Theme.displaySerif(26))
                    .foregroundStyle(Theme.ink)
                Text("Then $14.99 / year, cancel anytime.")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trustStrip
            VStack(alignment: .leading, spacing: 0) {
                timelineRow(icon: "lock.open.fill", title: "Today", text: "Full-length sessions on both devices, free.", showsLine: true)
                timelineRow(icon: "bell.fill", title: "Day 5", text: "Check History. How do you feel?", showsLine: true)
                timelineRow(icon: "star.fill", title: "Day 7", text: "First charge, only if you keep it. Cancel before then and pay nothing.", showsLine: false)
            }
            .padding(14)
            .background(Theme.aquaTint.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 10) {
                mockPlanCard(name: "Yearly", secondary: "7-day free trial · $1.25/mo", price: "$14.99 / year", badge: "SAVE 58%", selected: true)
                mockPlanCard(name: "Monthly", secondary: "7-day free trial", price: "$2.99 / month", badge: nil, selected: false)
                mockPlanCard(name: "Lifetime", secondary: "Pay once · never renews", price: "$29.99", badge: nil, selected: false)
            }
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.aqua)
                    Text("No payment due now")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                }
                Text("Start My 7-Day Free Trial")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.aqua, in: RoundedRectangle(cornerRadius: Theme.ctaRadius))
                Text("7-day free trial, then $14.99 / year. Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings.")
                    .font(.caption2)
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
            }
            legalFooter
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 48 : 20)
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity)
    }

    private func mockPlanCard(name: String, secondary: String?, price: String, badge: String?, selected: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(selected ? Theme.aqua : Theme.ink3.opacity(0.4), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if selected {
                    Circle().fill(Theme.aqua).frame(width: 12, height: 12)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.aqua, in: Capsule())
                    }
                }
                if let secondary {
                    Text(secondary)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.ink3)
                }
            }
            Spacer(minLength: 8)
            Text(price)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Theme.aqua : Theme.paper3, lineWidth: selected ? 2 : 1)
        }
    }

    private var offlinePlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            trustStrip
            compactFeatureList
            Spacer()
            Text("Connect to load plans")
                .font(.caption)
                .foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity)
            legalFooter
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 22)
        .padding(.top, displayCloseButton ? 48 : 20)
        .padding(.bottom, 14)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Copy

    private var ctaTitle: String {
        #if HAS_REVENUECAT
        guard let package = selectedPackage else { return "Continue" }
        if package.queasyPackageKind == .lifetime { return "Unlock Lifetime" }
        if subscriptions.isEligibleForIntroOffer(package), let trial = package.queasyIntroOfferLabel {
            return "Start My \(trial.capitalized)"
        }
        return "Start Queasy Pro"
        #else
        return "Continue"
        #endif
    }

    private var disclosureText: String? {
        #if HAS_REVENUECAT
        guard let package = selectedPackage else { return nil }
        let price = package.queasyPriceLabel
        if package.queasyPackageKind == .lifetime {
            return "\(price). One-time purchase. Lifetime access, no subscription."
        }
        let renew = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings."
        if subscriptions.isEligibleForIntroOffer(package), let trial = package.queasyIntroOfferLabel {
            return "\(trial.capitalized), then \(price). \(renew)"
        }
        return "\(price). \(renew)"
        #else
        return nil
        #endif
    }

    // MARK: - Actions

    #if HAS_REVENUECAT
    private func selectDefaultPackageIfNeeded() {
        guard selectedPackage == nil, !subscriptions.products.isEmpty else { return }
        selectedPackage = subscriptions.products.first { $0.queasyPackageKind == .yearly }
            ?? subscriptions.products.first
    }

    /// "$1.67/mo" anchor for the yearly card — the strongest known lever for
    /// steering hard-paywall selection to the annual plan.
    private func perMonthLabel(for package: Package) -> String? {
        guard package.queasyPackageKind == .yearly else { return nil }
        let yearly = package.storeProduct.price as Decimal
        guard yearly > 0 else { return nil }
        let handler = NSDecimalNumberHandler(
            roundingMode: .plain, scale: 2,
            raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false
        )
        let monthly = (yearly as NSDecimalNumber).dividing(by: 12, withBehavior: handler)
        let formatter = package.storeProduct.priceFormatter ?? {
            let f = NumberFormatter()
            f.numberStyle = .currency
            return f
        }()
        guard let text = formatter.string(from: monthly) else { return nil }
        return "\(text)/mo"
    }

    private func savingsPercent(for package: Package) -> Int? {
        guard package.queasyPackageKind == .yearly else { return nil }
        guard let monthly = subscriptions.products.first(where: { $0.queasyPackageKind == .monthly }) else { return nil }
        let yearlyPrice = package.storeProduct.price as Decimal
        let monthlyPrice = monthly.storeProduct.price as Decimal
        guard monthlyPrice > 0, yearlyPrice > 0 else { return nil }
        let yearlyAtMonthly = monthlyPrice * 12
        guard yearlyAtMonthly > yearlyPrice else { return nil }
        let saved = (yearlyAtMonthly - yearlyPrice) / yearlyAtMonthly
        return Int((saved as NSDecimalNumber).doubleValue * 100)
    }

    private func startPurchase() {
        guard let package = selectedPackage else { return }
        errorMessage = nil
        restoreMessage = nil
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                switch try await subscriptions.purchase(package) {
                case .purchased:
                    break
                case .pending:
                    restoreMessage = "Purchase is pending approval. Queasy Pro unlocks as soon as it's approved."
                case .cancelled:
                    errorMessage = nil
                }
            } catch {
                errorMessage = "Purchase didn't complete. Please try again."
            }
        }
    }

    private func startRestore() {
        errorMessage = nil
        restoreMessage = nil
        isRestoring = true
        Task {
            defer { isRestoring = false }
            await subscriptions.restorePurchases()
            if !subscriptions.isProSubscriber {
                restoreMessage = subscriptions.lastError ?? "No purchases found to restore."
            }
        }
    }
    #else
    private func startPurchase() {}
    private func startRestore() {
        isRestoring = true
        Task {
            defer { isRestoring = false }
            await subscriptions.refresh()
        }
    }
    #endif
}

#if HAS_REVENUECAT
private struct QueasyPlanCard: View {
    let package: Package
    let isSelected: Bool
    let showsTrialBadge: Bool
    let isBestValue: Bool
    let savingsPercent: Int?
    let perMonthLabel: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.aqua : Theme.ink3.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Theme.aqua)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(package.queasyDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if let savings = savingsPercent {
                            badge("SAVE \(savings)%")
                        } else if isBestValue {
                            badge("BEST VALUE")
                        }
                    }
                    if let secondary = secondaryLine {
                        Text(secondary)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.ink3)
                    }
                }

                Spacer(minLength: 8)

                Text(package.queasyPriceLabel)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Theme.aqua : Theme.paper3, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.aqua, in: Capsule())
    }

    private var secondaryLine: String? {
        var parts: [String] = []
        if showsTrialBadge, let trial = package.queasyIntroOfferLabel {
            parts.append(trial.capitalized)
        }
        if let perMonthLabel {
            parts.append(perMonthLabel)
        }
        if !parts.isEmpty {
            return parts.joined(separator: " · ")
        }
        if package.queasyPackageKind == .lifetime {
            return "Pay once · never renews"
        }
        return nil
    }
}
#endif
