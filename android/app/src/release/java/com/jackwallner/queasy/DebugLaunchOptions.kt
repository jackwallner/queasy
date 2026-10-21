package com.jackwallner.queasy

import android.content.Intent

/** Release and QA builds: launch extras never change anything. */
object DebugLaunchOptions {
    val learnCard: String? = null

    @Suppress("UNUSED_PARAMETER")
    fun apply(graph: AppGraph, intent: Intent?) = Unit
}
