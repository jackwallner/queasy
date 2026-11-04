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
        case .lifetime: return String(localized: "Lifetime")
        case .yearly: return String(localized: "Yearly")
        case .monthly: return String(localized: "Monthly")
        case .other: return storeProduct.localizedTitle
        }
    }

    /// The plan name analytics records, the same in every language.
    var queasyAnalyticsPlan: String {
        switch queasyPackageKind {
        case .lifetime: return "lifetime"
        case .yearly: return "yearly"
        case .monthly: return "monthly"
        case .other: return storeProduct.localizedTitle.lowercased()
        }
    }

    var queasyPriceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else {
            return storeProduct.localizedPriceString
        }
        let price = storeProduct.localizedPriceString
        let n = period.value
        switch period.unit {
        case .day: return n == 1 ? String(localized: "\(price) / day") : String(localized: "\(price) / \(n) days")
        case .week: return n == 1 ? String(localized: "\(price) / week") : String(localized: "\(price) / \(n) weeks")
        case .month: return n == 1 ? String(localized: "\(price) / month") : String(localized: "\(price) / \(n) months")
        case .year: return n == 1 ? String(localized: "\(price) / year") : String(localized: "\(price) / \(n) years")
        @unknown default: return price
        }
    }

    /// Picks the whole-sentence variant for the free-trial length. A trial
    /// counted in weeks reads in days, so it shares the day keys.
    private func queasyTrialCopy(
        day: (Int) -> String,
        month: (Int) -> String,
        year: (Int) -> String
    ) -> String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return day(period.value)
        case .week: return day(period.value * 7)
        case .month: return month(period.value)
        case .year: return year(period.value)
        @unknown default: return nil
        }
    }

    /// The free trial's length in days, when it is counted in days or weeks.
    var queasyIntroOfferDays: Int? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        default: return nil
        }
    }

    /// "7-Day Free Trial"
    var queasyIntroOfferTitle: String? {
        queasyTrialCopy(
            day: { String(localized: "\($0)-Day Free Trial") },
            month: { String(localized: "\($0)-Month Free Trial") },
            year: { String(localized: "\($0)-Year Free Trial") }
        )
    }

    /// "Try Queasy Pro\n7-day free trial."
    var queasyTryTrialHeadline: String? {
        queasyTrialCopy(
            day: { String(localized: "Try Queasy Pro\n\($0)-day free trial.") },
            month: { String(localized: "Try Queasy Pro\n\($0)-month free trial.") },
            year: { String(localized: "Try Queasy Pro\n\($0)-year free trial.") }
        )
    }

    /// "Start My 7-Day Free Trial"
    var queasyStartMyTrialTitle: String? {
        queasyTrialCopy(
            day: { String(localized: "Start My \($0)-Day Free Trial") },
            month: { String(localized: "Start My \($0)-Month Free Trial") },
            year: { String(localized: "Start My \($0)-Year Free Trial") }
        )
    }

    /// "7-Day Free Trial, then $14.99 / year." followed by the renewal terms.
    func queasyTrialDisclosure(terms: String) -> String? {
        let price = queasyPriceLabel
        return queasyTrialCopy(
            day: { String(localized: "\($0)-Day Free Trial, then \(price). \(terms)") },
            month: { String(localized: "\($0)-Month Free Trial, then \(price). \(terms)") },
            year: { String(localized: "\($0)-Year Free Trial, then \(price). \(terms)") }
        )
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
        // Test Store runs share one tester instead of a fresh anonymous customer
        // per install, so test runs don't inflate the live project's customer
        // charts. Never with the App Store key: real buyers would share one identity.
        #if DEBUG
        let qaUserID = ProcessInfo.processInfo.environment["RC_APP_USER_ID"] ?? "qa-ios"
        #else
        let qaUserID = "qa-ios"
        #endif
        let qaAppUserID = Self.apiKey.hasPrefix("test_") ? qaUserID : nil
        Purchases.configure(withAPIKey: Self.apiKey, appUserID: qaAppUserID)
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
            lastError = String(localized: "Couldn't load subscription options. Check your connection and try again.")
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
        guard package.queasyIntroOfferTitle != nil else { return false }
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
        let plan = package.queasyAnalyticsPlan
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
            lastError = isProSubscriber ? nil : String(localized: "No active Queasy Pro purchase found for this Apple ID.")
        } catch {
            lastError = String(localized: "Couldn't restore purchases. Try again.")
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

    /// Drives a Test Store purchase after the impression, so the `converted_*`
    /// half of the funnel record is exercised and not just the impression half.
    static var wantsPurchase: Bool {
        ProcessInfo.processInfo.arguments.contains("-rcfunnelprobepurchase")
    }
}
#endif
