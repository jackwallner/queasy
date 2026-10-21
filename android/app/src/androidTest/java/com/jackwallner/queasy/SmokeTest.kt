package com.jackwallner.queasy

import android.content.Intent
import android.os.Bundle
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.BySelector
import androidx.test.uiautomator.Direction
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The first-run path, the core loop and the free/paid/reviewer boundaries,
 * driven through UI Automator (test tags are resource ids). Each test runs on
 * a cleared install (`scripts/android-connected-tests.sh` clears app data
 * between tests). Launch extras are the debug-only `DebugLaunchOptions`.
 */
@RunWith(AndroidJUnit4::class)
class SmokeTest {
    private val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
    private val pkg = "com.jackwallner.queasy"

    private fun launch(extras: Bundle.() -> Unit = {}) {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val intent = context.packageManager.getLaunchIntentForPackage(pkg)!!.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtras(Bundle().apply { putBoolean("uiTest", true); extras() })
        }
        context.startActivity(intent)
        device.wait(Until.hasObject(By.pkg(pkg).depth(0)), 15_000)
    }

    private fun onboarded(extras: Bundle.() -> Unit = {}) = launch { putBoolean("onboarded", true); extras() }

    private fun find(selector: BySelector, timeout: Long = 10_000): UiObject2 =
        device.wait(Until.findObject(selector), timeout) ?: throw AssertionError("Not on screen: $selector")

    private fun findScrolling(selector: BySelector): UiObject2 {
        repeat(8) {
            device.wait(Until.findObject(selector), 1_200)?.let { return it }
            device.findObject(By.scrollable(true))?.scroll(Direction.DOWN, 0.7f)
        }
        return find(selector)
    }

    private fun tag(id: String) = By.res(id)

    @Test fun firstRunGoesStraightToTheFreeAppWithNoPaywall() {
        launch()
        find(By.text("Four things to try\nwhen you feel sick"))
        repeat(3) { find(tag("onboarding-continue")).click(); Thread.sleep(500) }
        find(By.text("Your phone does\nthe tapping"))
        find(By.text("Get Started")).click()
        find(By.text("Feeling queasy?"))
        find(tag("quick-start"))
        find(By.text("Level 5 · 2 min on this phone"))
        assertNull(device.findObject(tag("paywall")))
    }

    @Test fun checkInSuggestsToneFirstForMotionSickness() {
        onboarded()
        find(tag("start-checkin")).click()
        find(By.text("What kind of queasy?"))
        find(tag("cause-motion")).click()
        find(By.text("How bad is it right now?"))
        find(tag("severity-4")).click()
        find(By.text("Still moving?"))
        find(tag("exposed-yes")).click()
        find(tag("ate-no")).click()
        find(By.text("SUGGESTED FOR MOTION SICKNESS"))
        find(By.text("Play the Tone"))
        find(By.text("100 Hz · one minute · headphones"))
        find(tag("mode-pulse")).click()
        // Severity 4, still moving, empty stomach: level 9 for 20 minutes, capped to 2 free.
        find(By.text("9"))
        find(By.text("2 minutes on the free plan"))
        findScrolling(By.text("Free sessions run 2 minutes. Pro runs the full 20."))
        findScrolling(By.text("If you're a passenger, face forward and sit up front if you can."))
    }

    @Test fun freePulseIsCappedAndTheCapOpensThePaywall() {
        onboarded { putBoolean("previewStore", true); putString("screen", "mode-pulse") }
        find(By.text("2 minutes"))
        find(tag("mode-unlock-length")).click()
        find(tag("paywall"))
        find(By.text("QUEASY PRO"))
        find(tag("plan-yearly"))
        find(By.text("$14.99 / year"))
        find(By.text("Start My 7-Day Free Trial"))
        val disclosure = find(tag("paywall-disclosure")).text
        assertTrue(disclosure, disclosure.startsWith("7-Day Free Trial, then $14.99 / year.") && "Google Play" in disclosure)
        find(tag("plan-lifetime")).click()
        find(By.text("Unlock Lifetime"))
        find(tag("paywall-close")).click()
        find(tag("mode-start-phone"))
    }

    @Test fun proRunsTheFullLengthWithNoUpsell() {
        onboarded { putBoolean("demoPro", true); putString("screen", "mode-pulse") }
        find(By.text("15 minutes"))
        assertNull(device.wait(Until.findObject(tag("mode-unlock-length")), 1_500))
    }

    @Test fun aSessionIsRatedAndLandsInHistory() {
        onboarded { putString("screen", "session-breathe") }
        find(By.text("Follow the breath"))
        find(tag("tone-toggle"))
        find(tag("end-session")).click()
        find(By.text("How do you feel now?"))
        find(tag("after-feeling-better")).click()
        find(tag("tab-history")).click()
        find(By.text("Breathe · Illness / other"))
        find(By.text("−2"))
    }

    @Test fun pulseLevelCanBeTurnedUpAndDownLive() {
        onboarded { putString("screen", "session-pulse") }
        find(By.text("Level 5"))
        find(tag("intensity-up")).click()
        find(By.text("Level 6"))
        find(tag("intensity-down")).click()
        find(tag("intensity-down")).click()
        find(By.text("Level 4"))
        find(tag("cancel-session")).click()
        find(By.text("Feeling queasy?"))
    }

    @Test fun freeHistoryKeepsOlderSessionsBehindPro() {
        onboarded { putBoolean("seedDemo", true); putString("tab", "history") }
        find(By.text("mode that\nhelps most"))
        findScrolling(tag("history-unlock"))
    }

    @Test fun proHistoryShowsEverySession() {
        onboarded { putBoolean("seedDemo", true); putBoolean("demoPro", true); putString("tab", "history") }
        find(By.text("mode that\nhelps most"))
        repeat(10) { device.findObject(By.scrollable(true))?.scroll(Direction.DOWN, 0.9f) }
        find(By.text("Touch and hold a session to delete it."))
        assertNull(device.findObject(tag("history-unlock")))
    }

    @Test fun pressRemindersAreProAndOpenThePaywallWhenFree() {
        onboarded { putBoolean("previewStore", true); putString("tab", "settings") }
        find(tag("press-reminders")).click()
        find(tag("paywall"))
        find(By.text("Restore Purchases"))
    }

    @Test fun aPlayReviewerCodeUnlocksProAndAWrongOneDoesNot() {
        val code = InstrumentationRegistry.getArguments().getString("reviewCode")
        assertNotNull("pass -e reviewCode <code from ~/.queasy_credentials>", code)
        onboarded { putString("tab", "settings") }
        find(By.text("See Queasy Pro"))
        findScrolling(tag("settings-version")).longClick()
        find(tag("review-code-field")).text = "WRONG-CODE"
        find(By.text("Unlock")).click()
        find(By.text("That code didn't match."))
        find(tag("review-code-field")).text = code
        find(By.text("Unlock")).click()
        device.findObject(By.scrollable(true))?.scroll(Direction.UP, 1f)
        find(tag("pro-active"))
    }

    @Test fun theTestStoreOfferingLoadsFromRevenueCat() {
        onboarded { putString("screen", "paywall") }
        find(tag("paywall"))
        find(tag("plan-yearly"), timeout = 45_000)
        find(tag("plan-monthly"))
        find(tag("plan-lifetime"))
        val disclosure = find(tag("paywall-disclosure")).text
        assertTrue(disclosure, "Auto-renews" in disclosure)
    }

    @Test fun learnExplainsWhatPulseIsNot() {
        onboarded { putString("tab", "learn") }
        find(tag("learn-pulse")).click()
        find(By.textContains("is not acupressure and not nerve stimulation"))
        find(tag("learn-tone")).click()
        find(By.textContains("Nagoya University group"))
        // One topic open at a time.
        assertTrue(device.wait(Until.gone(By.textContains("is not acupressure")), 5_000))
    }
}
