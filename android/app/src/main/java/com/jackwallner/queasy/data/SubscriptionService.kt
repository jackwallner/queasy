package com.jackwallner.queasy.data

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.queasy.BuildConfig
import com.revenuecat.purchases.CustomerInfo
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Offering
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesException
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.interfaces.UpdatedCustomerInfoListener
import com.revenuecat.purchases.models.Period
import com.revenuecat.purchases.paywalls.events.CustomPaywallImpressionParams
import kotlin.coroutines.cancellation.CancellationException

enum class PurchaseOutcome { PURCHASED, PENDING, CANCELLED }

internal fun purchaseOutcome(code: PurchasesErrorCode, userCancelled: Boolean): PurchaseOutcome? = when {
    userCancelled || code == PurchasesErrorCode.PurchaseCancelledError -> PurchaseOutcome.CANCELLED
    code == PurchasesErrorCode.PaymentPendingError -> PurchaseOutcome.PENDING
    else -> null
}

class PurchaseException(message: String) : Exception(message)

private fun Period.toPlanPeriod(): PlanPeriod? {
    val unit = when (unit) {
        Period.Unit.DAY -> PeriodUnit.DAY
        Period.Unit.WEEK -> PeriodUnit.WEEK
        Period.Unit.MONTH -> PeriodUnit.MONTH
        Period.Unit.YEAR -> PeriodUnit.YEAR
        else -> return null
    }
    return PlanPeriod(value, unit)
}

/**
 * RevenueCat behind Queasy Pro. Debug builds use the project's Test Store key
 * and release builds the Play key; neither ever runs on the other. Any active
 * entitlement unlocks Pro, as on iOS, so a renamed entitlement can't lock out
 * a payer (the dashboard's lookup key is "Queasy Pro").
 */
class SubscriptionService(
    private val context: Context,
    private val defaults: KeyValueStore,
    private val diagnostics: ConversionDiagnostics,
) {
    private val reviewAccess = ReviewAccess(defaults, BuildConfig.PLAY_REVIEW_CODE_SHA256)
    private var entitlementActive by mutableStateOf(defaults.getBoolean(CACHED_PRO))
    private var overrideActive by mutableStateOf(BuildConfig.DEBUG && defaults.getBoolean(LOCAL_OVERRIDE))
    private var reviewGranted by mutableStateOf(reviewAccess.isGranted)

    /** The single gate the whole app reads. */
    val isPro: Boolean get() = entitlementActive || overrideActive || reviewGranted

    val hasReviewAccess: Boolean get() = reviewGranted

    var isConfigured by mutableStateOf(false)
        private set
    var isLoadingProducts by mutableStateOf(false)
        private set
    var lastError by mutableStateOf<String?>(null)
        private set
    var plans by mutableStateOf<List<Plan>>(emptyList())
        private set
    /** Until customer info has answered, never promise a trial (it may already be used). */
    private var introEligibilityResolved by mutableStateOf(false)
    private var hasSubscriptionHistory by mutableStateOf(false)

    private var packages: List<Package> = emptyList()
    private var offering: Offering? = null
    private var customerInfoLoaded = false
    private var isPreview = false
    private val impressionsThisSession = mutableSetOf<String>()

    fun setLocalOverride(value: Boolean) {
        if (!BuildConfig.DEBUG) return
        defaults.putBoolean(LOCAL_OVERRIDE, value)
        overrideActive = value
    }

    /** Debug screenshots and UI tests: a local plan stack with no store behind it. */
    fun loadPreviewPlans(preview: List<Plan>, trialUsed: Boolean = false) {
        if (!BuildConfig.DEBUG) return
        plans = preview
        packages = emptyList()
        hasSubscriptionHistory = trialUsed
        introEligibilityResolved = true
        isConfigured = true
        isPreview = true
        lastError = null
    }

    fun activateReviewAccess(code: String): Boolean {
        if (!reviewAccess.activate(code)) return false
        reviewGranted = true
        return true
    }

    suspend fun start() {
        if (!configureIfNeeded()) return
        refreshCustomerInfo()
        fetchProducts()
    }

    suspend fun refreshCustomerInfo() {
        if (isPreview || !configureIfNeeded()) return
        runCatching { Purchases.sharedInstance.awaitCustomerInfo() }
            .onSuccess(::apply)
            .onFailure { if (it is CancellationException) throw it }
    }

    suspend fun fetchProducts() {
        if (isPreview || isLoadingProducts) return
        if (!configureIfNeeded()) {
            lastError = "Couldn't load subscription options. Check your connection and try again."
            return
        }
        isLoadingProducts = true
        try {
            val offerings = Purchases.sharedInstance.awaitOfferings()
            val offering = offerings.all[OFFERING_ID] ?: offerings.current
            val loaded = offering?.availablePackages.orEmpty().sortedWith(
                compareBy<Package> { kind(it).ordinal }.thenBy { it.product.id },
            )
            this.offering = offering
            packages = loaded
            plans = loaded.map(::plan)
            lastError = if (loaded.isEmpty()) "Couldn't load subscription options. Check your connection and try again." else null
            if (!customerInfoLoaded) refreshCustomerInfo()
            introEligibilityResolved = customerInfoLoaded
        } catch (error: CancellationException) {
            throw error
        } catch (_: Throwable) {
            lastError = "Couldn't load subscription options. Check your connection and try again."
        } finally {
            isLoadingProducts = false
        }
    }

    /** Defaults to not eligible until RevenueCat answers, so nobody is promised a trial they already used. */
    fun isEligibleForIntroOffer(plan: Plan): Boolean =
        plan.trial != null && introEligibilityResolved && !hasSubscriptionHistory

    /** Feeds RevenueCat's paywall encounters; a custom paywall emits none of its own. */
    fun trackPaywallImpression(id: String, oncePerSession: Boolean = false) {
        if (oncePerSession && !impressionsThisSession.add(id)) return
        diagnostics.recordPitchView(id)
        if (!isConfigured || isPreview) return
        syncConversionAttributes()
        val params = offering?.let { CustomPaywallImpressionParams(id, it) } ?: CustomPaywallImpressionParams(id)
        runCatching { Purchases.sharedInstance.trackCustomPaywallImpression(params) }
    }

    fun syncConversionAttributes() {
        if (!isConfigured || isPreview) return
        val attributes = diagnostics.subscriberAttributes
        if (attributes.isEmpty()) return
        runCatching { Purchases.sharedInstance.setAttributes(attributes) }
    }

    /** A cancel is an outcome, not an error. Throws only with a user-facing message. */
    suspend fun purchase(activity: Activity, plan: Plan): PurchaseOutcome {
        if (isPreview) {
            setLocalOverride(true)
            return PurchaseOutcome.PURCHASED
        }
        val pkg = packages.firstOrNull { it.identifier == plan.packageId }
        if (!configureIfNeeded() || pkg == null) throw PurchaseException(UNAVAILABLE)
        val startedTrial = isEligibleForIntroOffer(plan)
        val option = if (startedTrial) pkg.product.defaultOption else pkg.product.subscriptionOptions?.basePlan
        val params = if (option != null) {
            PurchaseParams.Builder(activity, option).presentedOfferingContext(pkg.presentedOfferingContext).build()
        } else {
            PurchaseParams.Builder(activity, pkg).build()
        }
        return try {
            val result = Purchases.sharedInstance.awaitPurchase(params)
            apply(result.customerInfo)
            if (!entitlementActive) refreshCustomerInfo()
            if (!entitlementActive) return PurchaseOutcome.PENDING
            diagnostics.recordConversion(pkg.product.id, startedTrial, pkg.presentedOfferingContext.offeringIdentifier)
            syncConversionAttributes()
            PurchaseOutcome.PURCHASED
        } catch (error: PurchasesTransactionException) {
            purchaseOutcome(error.code, error.userCancelled)
                ?: throw PurchaseException("Purchase didn't complete. Please try again.")
        }
    }

    /** Leaves [lastError] set when nothing was restored, like iOS. */
    suspend fun restorePurchases() {
        lastError = null
        if (isPreview) return
        if (!configureIfNeeded()) {
            lastError = UNAVAILABLE
            return
        }
        try {
            apply(Purchases.sharedInstance.awaitRestore())
            if (!entitlementActive) lastError = "No active Queasy Pro purchase found for this Google Play account."
        } catch (error: CancellationException) {
            throw error
        } catch (error: PurchasesException) {
            lastError = if (error.code == PurchasesErrorCode.PaymentPendingError) {
                "Google Play is still processing your payment. Queasy Pro unlocks as soon as it completes."
            } else {
                "Couldn't restore purchases. Try again."
            }
        } catch (_: Throwable) {
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    private fun apply(info: CustomerInfo) {
        customerInfoLoaded = true
        hasSubscriptionHistory = info.allExpirationDatesByProduct.isNotEmpty()
        introEligibilityResolved = packages.isNotEmpty()
        entitlementActive = info.entitlements.active.isNotEmpty()
        defaults.putBoolean(CACHED_PRO, entitlementActive)
    }

    private fun configureIfNeeded(): Boolean {
        if (isConfigured) return true
        val key = BuildConfig.REVENUECAT_API_KEY
        if (key.isBlank()) return false
        // Never the production Play key in a debug build, and never a test key in release.
        if (BuildConfig.DEBUG && key.startsWith("goog_")) return false
        if (!BuildConfig.DEBUG && !key.startsWith("goog_")) return false
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
        val builder = PurchasesConfiguration.Builder(context, key)
        // Test Store runs share one tester instead of a fresh anonymous customer
        // per install, so test runs don't inflate the live project's New and
        // Active Customers. Never with the Play key: real buyers would share one
        // identity.
        if (key.startsWith("test_")) builder.appUserID(QA_APP_USER_ID)
        Purchases.configure(builder.build())
        Purchases.sharedInstance.updatedCustomerInfoListener = UpdatedCustomerInfoListener { apply(it) }
        isConfigured = true
        return true
    }

    private fun kind(pkg: Package): PackageKind = when (pkg.packageType) {
        PackageType.LIFETIME -> PackageKind.LIFETIME
        PackageType.ANNUAL -> PackageKind.YEARLY
        PackageType.MONTHLY -> PackageKind.MONTHLY
        else -> PackageKind.fromIdentifiers(pkg.identifier, pkg.product.id)
    }

    private fun plan(pkg: Package): Plan {
        val price = pkg.product.price
        val free = pkg.product.subscriptionOptions?.firstOrNull { it.freePhase != null }?.freePhase
            ?: pkg.product.defaultOption?.freePhase
        return Plan(
            packageId = pkg.identifier,
            productId = pkg.product.id,
            kind = kind(pkg),
            priceMicros = price.amountMicros,
            priceFormatted = price.formatted,
            currencyCode = price.currencyCode,
            period = pkg.product.period?.toPlanPeriod(),
            trial = free?.billingPeriod?.toPlanPeriod(),
            title = pkg.product.title,
        )
    }

    companion object {
        private const val QA_APP_USER_ID = "qa-android"
        private const val OFFERING_ID = "default"
        private const val LOCAL_OVERRIDE = "subscription.localProOverride"
        private const val CACHED_PRO = "isProSubscriber"
        private const val UNAVAILABLE = "Google Play isn't reachable right now. Check your connection and try again."

        const val PENDING_MESSAGE = "Purchase is pending approval. Queasy Pro unlocks as soon as it's approved."
        const val AUTO_RENEW_DISCLOSURE =
            "Auto-renews unless cancelled before the end of the current period. Manage or cancel in Google Play › Payments & subscriptions."
    }
}

internal fun String.capitalizeWords(): String =
    split(" ").joinToString(" ") { word -> word.split("-").joinToString("-") { it.replaceFirstChar(Char::uppercaseChar) } }
