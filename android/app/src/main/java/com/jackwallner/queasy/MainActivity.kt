package com.jackwallner.queasy

import android.Manifest
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.lifecycle.lifecycleScope
import com.jackwallner.queasy.ui.LocalGraph
import com.jackwallner.queasy.ui.RootScreen
import com.jackwallner.queasy.ui.theme.QueasyTheme
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch

@OptIn(ExperimentalComposeUiApi::class)
class MainActivity : ComponentActivity() {
    private val graph: AppGraph get() = (application as QueasyApplication).graph
    private var permissionAnswer: CompletableDeferred<Boolean>? = null

    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        permissionAnswer?.complete(granted)
        permissionAnswer = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val graph = graph
        graph.reminders.requestPermission = {
            val answer = CompletableDeferred<Boolean>()
            permissionAnswer = answer
            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
            answer.await()
        }
        if (savedInstanceState == null) {
            DebugLaunchOptions.apply(graph, intent)
            graph.diagnostics.recordAppOpen()
            graph.review.recordAppLaunch()
        }
        // Light-only like iOS: dark bar icons over the seafoam wash.
        val bars = SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT)
        enableEdgeToEdge(statusBarStyle = bars, navigationBarStyle = bars)
        lifecycleScope.launch {
            graph.subscriptions.start()
            if (graph.subscriptions.isPro) graph.reminders.refresh() else graph.reminders.suspendForNonSubscriber()
        }
        setContent {
            CompositionLocalProvider(LocalGraph provides graph) {
                QueasyTheme {
                    // Test tags double as resource ids so UI Automator and capture scripts can find controls.
                    Box(Modifier.semantics { testTagsAsResourceId = true }) {
                        RootScreen(this@MainActivity)
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Renewals, restores and late grants flip the app promptly.
        lifecycleScope.launch { graph.subscriptions.refreshCustomerInfo() }
    }

    override fun onStop() {
        super.onStop()
        graph.subscriptions.syncConversionAttributes()
    }

    override fun onDestroy() {
        if (isFinishing) graph.reminders.requestPermission = null
        super.onDestroy()
    }
}
