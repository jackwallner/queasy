import Foundation
import Observation
#if HAS_REVENUECAT
@preconcurrency import RevenueCat
#endif

enum PurchaseState {
    case purchased
    case cancelled
    case pending
}

#if HAS_REVENUECAT
enum QueasyPackageKind: Int {
    case yearly = 0
    case monthly = 1
    case lifetime = 2
    case other = 3
}

extension QueasyPackageKind {
    init(package: Package) {
        switch package.packageType {
        case .lifetime:
            self = .lifetime
        case .annual:
            self = .yearly
        case .monthly:
            self = .monthly
        default:
            let ids = [package.identifier, package.storeProduct.productIdentifier].map { $0.lowercased() }
            if ids.contains(where: { $0.contains("lifetime") }) {
                self = .lifetime
            } else if ids.contains(where: { $0.contains("yearly") || $0.contains("annual") }) {
                self = .yearly
            } else if ids.contains(where: { $0.contains("monthly") }) {
                self = .monthly
            } else {
                self = .other
            }
        }
    }
}

extension Package {
    var queasyPackageKind: QueasyPackageKind {
        QueasyPackageKind(package: self)
    }

    var queasyDisplayName: String {
        switch queasyPackageKind {
        case .lifetime: return "Lifetime"
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        case .other: return storeProduct.localizedTitle
        }
    }

    var queasyPriceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else {
            return storeProduct.localizedPriceString
        }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.value == 1 {
            return "\(storeProduct.localizedPriceString) / \(unit)"
        }
        return "\(storeProduct.localizedPriceString) / \(period.value) \(unit)"
    }

    var queasyIntroOfferLabel: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        if period.unit == .week {
            return "\(period.value * 7)-day free trial"
        }
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = ""
        }
        return "\(period.value)-\(unit) free trial"
    }
}

extension Offering {
    /// Yearly first (default + trial), monthly second, lifetime for sub refusers.
    var queasySortedPackages: [Package] {
        availablePackages.sorted {
            let lhs = $0.queasyPackageKind
            let rhs = $1.queasyPackageKind
            if lhs.rawValue != rhs.rawValue { return lhs.rawValue < rhs.rawValue }
            return $0.storeProduct.productIdentifier < $1.storeProduct.productIdentifier
        }
    }
}
#endif

/// RevenueCat wrapper. The `pro` entitlement gates the app behind the hard paywall.
@MainActor
@Observable
final class SubscriptionService: NSObject {
    static let shared = SubscriptionService()

    /// RevenueCat public SDK key (project Queasy, app app57b0d19514).
    /// Debug builds use Queasy's RevenueCat Test Store so simulator purchases
    /// never create customers or transactions in the production project.
    #if DEBUG
    static let apiKey = "test_yFqWXQqRnLbdPIreheWeQEQVDOI"
    #else
    static let apiKey = "appl_fQcEGmmjTrfdXEqnfEzaCbtzbWK"
    #endif

    static let proEntitlement = "pro"

    private(set) var isProSubscriber: Bool = false
    private(set) var isConfigured: Bool = false

    #if HAS_REVENUECAT
    private(set) var products: [Package] = []
    private(set) var isLoadingProducts: Bool = false
    private(set) var lastError: String?
    private(set) var introEligibility: [String: Bool] = [:]
    private var paywallImpressionsThisSession: Set<String> = []
    #endif

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: queasyAppGroupID)
    }

    func configure() {
        #if DEBUG
        // Simulator/screenshot hook: keep the local override authoritative and
        // skip RevenueCat entirely so a customerInfo refresh can't undo it.
        if ProcessInfo.processInfo.arguments.contains("-QueasyProOverride") {
            isProSubscriber = true
            return
        }
        #endif
        #if HAS_REVENUECAT
        #if targetEnvironment(simulator)
        // A simulator must never be allowed to use the production project.
        #if DEBUG
        // The one exception, behind a launch argument: the Test Store key is a
        // separate RevenueCat app inside the same project, so a probe run cannot
        // touch App Store customers, revenue or charts. See RevenueCatProbe.
        if RevenueCatProbe.isEnabled, !isConfigured {
            Purchases.logLevel = .debug
            Purchases.configure(
                with: Configuration.Builder(withAPIKey: RevenueCatProbe.testStoreKey)
                    .with(appUserID: RevenueCatProbe.appUserID)
                    .build()
            )
            Purchases.shared.delegate = self
            isConfigured = true
            return
        }
        #endif
        guard Self.apiKey.hasPrefix("test_") else {
            isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
            return
        }
        #endif
        guard !isConfigured, !Self.apiKey.isEmpty else {
            isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
            return
        }
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: Self.apiKey)
        Purchases.shared.delegate = self
        isConfigured = true
        Task { await refresh() }
        Task { await fetchProducts() }
        #endif
        isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
    }

    func refresh() async {
        #if HAS_REVENUECAT
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            applyProStatus(from: info)
        } catch {
            // Network errors leave previous state intact.
        }
        #else
        isProSubscriber = sharedDefaults?.bool(forKey: "isProSubscriber") ?? false
        #endif
    }

    #if HAS_REVENUECAT
    func fetchProducts() async {
        guard isConfigured else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.offering(identifier: "default") ?? offerings.current
            products = offering?.queasySortedPackages ?? []
            lastError = nil
            await refreshIntroEligibility()
        } catch {
            lastError = "Couldn't load subscription options. Check your connection and try again."
        }
    }

    private func refreshIntroEligibility() async {
        let identifiers = products
            .filter { $0.storeProduct.introductoryDiscount != nil }
            .map(\.storeProduct.productIdentifier)
        guard !identifiers.isEmpty else {
            introEligibility = [:]
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: identifiers)
        introEligibility = result.mapValues { $0.status == .eligible }
    }

    /// Default to NOT eligible until RevenueCat confirms, so we never promise a
    /// trial to someone who already used it and would be charged immediately.
    func isEligibleForIntroOffer(_ package: Package) -> Bool {
        guard package.queasyIntroOfferLabel != nil else { return false }
        return introEligibility[package.storeProduct.productIdentifier] ?? false
    }

    /// Mirrors the on-device paywall record onto the RevenueCat customer.
    ///
    /// Attributes rather than extra impressions: RevenueCat treats every
    /// impression id as a paywall encounter, so funnel steps sent that way would
    /// drive the encounter rate to 100% and destroy the one server-side number
    /// that currently works.
    ///
    /// `isConfigured` is the load-bearing guard: `Purchases.shared` traps when
    /// RevenueCat was never configured, which is every simulator run.
    ///
    /// `setAttributes` only queues. RevenueCat uploads when the app backgrounds
    /// or folds the queue into the POST that creates a customer, so a probe run
    /// has to background the app before reading anything back.
    func syncConversionAttributes() {
        guard isConfigured else { return }
        let attributes = ConversionDiagnostics.subscriberAttributes
        guard !attributes.isEmpty else { return }
        Purchases.shared.attribution.setAttributes(attributes)
    }

    func trackPaywallImpression(id: String, oncePerSession: Bool = false) {
        guard isConfigured else { return }
        if oncePerSession {
            guard !paywallImpressionsThisSession.contains(id) else { return }
            paywallImpressionsThisSession.insert(id)
        }
        ConversionDiagnostics.recordPitchView(impressionID: id)
        syncConversionAttributes()
        Purchases.shared.trackCustomPaywallImpression(
            CustomPaywallImpressionParams(paywallId: id)
        )
        AnalyticsService.paywallShown()
    }

    @discardableResult
    func purchase(_ package: Package) async throws -> PurchaseState {
        guard isConfigured else { throw PurchaseError.notConfigured }
        let plan = package.queasyDisplayName.lowercased()
        AnalyticsService.purchaseAttempted(plan: plan)
        let startedTrial = isEligibleForIntroOffer(package)
        let result = try await Purchases.shared.purchase(package: package)
        applyProStatus(from: result.customerInfo)
        if result.userCancelled {
            return .cancelled
        }
        if isProSubscriber {
            AnalyticsService.purchaseCompleted(plan: plan)
            ConversionDiagnostics.recordConversion(
                plan: package.storeProduct.productIdentifier,
                startedTrial: startedTrial,
                offeringID: package.presentedOfferingContext.offeringIdentifier
            )
            syncConversionAttributes()
            return .purchased
        }
        return .pending
    }

    func restorePurchases() async {
        guard isConfigured else { return }
        lastError = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            applyProStatus(from: info)
            lastError = isProSubscriber ? nil : "No active Queasy Pro purchase found for this Apple ID."
        } catch {
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    private func applyProStatus(from info: CustomerInfo) {
        // Prefer the canonical "pro" id but accept ANY active entitlement, so a
        // differently named entitlement in the dashboard can't lock out payers.
        let active = info.entitlements.active
        isProSubscriber = active[Self.proEntitlement]?.isActive == true || !active.isEmpty
        sharedDefaults?.set(isProSubscriber, forKey: "isProSubscriber")
    }

    enum PurchaseError: Error {
        case notConfigured
    }
    #endif

    /// Debug/testing hook — flips the entitlement locally without RevenueCat.
    func setLocalOverride(isPro: Bool) {
        isProSubscriber = isPro
        sharedDefaults?.set(isPro, forKey: "isProSubscriber")
    }
}

#if HAS_REVENUECAT
extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            SubscriptionService.shared.applyProStatus(from: customerInfo)
        }
    }
}
#endif

#if DEBUG && HAS_REVENUECAT
/// Simulator-only proof path for the fleet-wide funnel attributes.
///
/// Under the normal rules the attributes cannot be verified on a simulator: the
/// production key must never be configured there, so RevenueCat is never
/// configured, so nothing is ever sent, so a physical device is the only
/// witness. The Test Store key is a different RevenueCat app inside the same
/// project, so a probe run cannot touch App Store customers, revenue or charts.
///
/// DEBUG only, and only with the launch argument, so it cannot reach a Release
/// build or an ordinary simulator run.
enum RevenueCatProbe {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-rcfunnelprobe")
    }

    static let testStoreKey = "test_yFqWXQqRnLbdPIreheWeQEQVDOI"

    static var appUserID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_USER"] ?? "funnel-probe-queasy"
    }

    static var impressionID: String {
        ProcessInfo.processInfo.environment["RC_PROBE_SURFACE"] ?? "queasy_after_session"
    }
}
#endif
