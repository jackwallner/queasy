package com.jackwallner.queasy.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.queasy.R

/**
 * Tide design system from `Shared/Utilities/Theme.swift`: seafoam canvas, deep
 * petrol ink, aqua brand. The iOS app is light-only, and so is this port.
 */
object Tide {
    val paper = Color(0xFFEAF3F2)
    val paper2 = Color.White
    val paper3 = Color(0xFFF2F8F7)
    val ink = Color(0xFF24393E)
    val ink2 = Color(0xFF5C7378)
    val ink3 = Color(0xFF8CA2A6)
    val aqua = Color(0xFF55B5A9)
    val aquaDeep = Color(0xFF3E9A8E)
    val aquaTint = Color(0xFFDAF0EC)
    val sand = Color(0xFFE8C896)
    val sandTint = Color(0xFFFAF1E1)
    val coral = Color(0xFFE8938A)
    val coralTint = Color(0xFFFAE8E5)

    val cardRadius = 24.dp
    val cardPadding = 22.dp
    val ctaRadius = 28.dp

    /** 1-5 check-in severity to a calm-to-urgent colour. */
    fun severityColor(severity: Int): Color = when {
        severity <= 2 -> aqua
        severity == 3 -> sand
        else -> coral
    }

    /** Page wash: aqua cresting at the top, fading into the seafoam canvas. */
    val tideWash = Brush.verticalGradient(0f to aquaTint, 0.5f to paper, 1f to paper)

    /** CTA fill: aqua with a slightly deeper foot so buttons read dimensional. */
    val ctaGradient = Brush.verticalGradient(listOf(aqua, aquaDeep))
}

/** The ritual serif italic (iOS uses New York italic; Newsreader is its open-licence match). */
val SerifItalic = FontFamily(Font(R.font.newsreader_italic, FontWeight.Normal, FontStyle.Italic))

/** Rounded numerals and headings (SF Rounded on iOS). */
val Rounded = FontFamily(Font(R.font.nunito))

object TideType {
    fun display(size: TextUnit) = TextStyle(fontFamily = SerifItalic, fontStyle = FontStyle.Italic, fontSize = size, color = Tide.ink)

    fun rounded(size: TextUnit, weight: FontWeight = FontWeight.SemiBold) =
        TextStyle(fontFamily = Rounded, fontWeight = weight, fontSize = size, fontFeatureSettings = "tnum")

    // iOS Dynamic Type sizes at the default setting.
    val headline = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold, color = Tide.ink)
    val body = TextStyle(fontSize = 17.sp, color = Tide.ink)
    val callout = TextStyle(fontSize = 16.sp, lineHeight = 22.sp, color = Tide.ink2)
    val subheadline = TextStyle(fontSize = 15.sp, lineHeight = 20.sp, color = Tide.ink2)
    val footnote = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, color = Tide.ink2)
    val caption = TextStyle(fontSize = 12.sp, lineHeight = 16.sp, color = Tide.ink2)
    val caption2 = TextStyle(fontSize = 11.sp, lineHeight = 14.sp, color = Tide.ink3)
    val sectionLabel = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.5.sp, color = Tide.ink3)
}

@Composable
fun QueasyTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Tide.aqua,
            onPrimary = Color.White,
            secondary = Tide.aquaDeep,
            background = Tide.paper,
            surface = Tide.paper2,
            onSurface = Tide.ink,
            onBackground = Tide.ink,
            surfaceVariant = Tide.paper3,
            onSurfaceVariant = Tide.ink2,
            outline = Tide.ink3,
            error = Tide.coral,
        ),
        content = content,
    )
}
