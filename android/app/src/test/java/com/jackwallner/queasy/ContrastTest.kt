package com.jackwallner.queasy

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.jackwallner.queasy.ui.theme.Tide
import org.junit.Assert.assertTrue
import org.junit.Test

/** Android twin of iOS fix 44aa4ff. */
class ContrastTest {
    // 44aa4ff: text in the brand aqua misses 4.5:1 on paper and white; the ink variant clears it.

    private fun contrast(a: Color, b: Color): Double {
        val (hi, lo) = listOf(a.luminance(), b.luminance()).sortedDescending()
        return (hi + 0.05) / (lo + 0.05)
    }

    @Test fun aquaInkTextClearsContrastOnPaperAndWhite() {
        for (background in listOf(Tide.paper, Tide.paper2, Tide.paper3)) {
            assertTrue(contrast(Tide.aquaInk, background) >= 4.5)
        }
        assertTrue(contrast(Tide.aqua, Tide.paper2) < 4.5)
    }
}
