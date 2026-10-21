package com.jackwallner.queasy.ui.theme

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.queasy.model.BreathPhase
import com.jackwallner.queasy.model.BreathePattern

/** Card surface opaque so its soft shadow never shows through (see the fleet port notes). */
private val CardFill = Color(0xFFFBFDFD)

/** iOS `tideCard()`: a near-white card with a hairline edge and a soft drop on the tide wash. */
fun Modifier.tideCard(radius: Dp = Tide.cardRadius): Modifier {
    val shape = RoundedCornerShape(radius)
    return this
        .shadow(12.dp, shape, ambientColor = Tide.ink.copy(alpha = 0.10f), spotColor = Tide.ink.copy(alpha = 0.14f))
        .background(CardFill, shape)
        .border(1.dp, Tide.ink.copy(alpha = 0.06f), shape)
        .clip(shape)
}

@Composable
fun TideCard(
    modifier: Modifier = Modifier,
    radius: Dp = Tide.cardRadius,
    padding: PaddingValues = PaddingValues(Tide.cardPadding),
    horizontalAlignment: Alignment.Horizontal = Alignment.Start,
    spacing: Dp = 12.dp,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier.fillMaxWidth().tideCard(radius).padding(padding),
        verticalArrangement = Arrangement.spacedBy(spacing),
        horizontalAlignment = horizontalAlignment,
        content = content,
    )
}

/** Primary CTA: aqua gradient, white rounded label, a press that sinks slightly. */
@Composable
fun TideButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    hero: Boolean = false,
    enabled: Boolean = true,
    tag: String? = null,
    content: (@Composable BoxScope.() -> Unit)? = null,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val shape = RoundedCornerShape(Tide.ctaRadius)
    Box(
        modifier
            .fillMaxWidth()
            .height(if (hero) 64.dp else 52.dp)
            .scale(if (pressed) 0.98f else 1f)
            .shadow(if (pressed) 2.dp else 8.dp, shape, ambientColor = Tide.aqua, spotColor = Tide.aqua)
            .background(Tide.ctaGradient, shape)
            .clip(shape)
            .clickable(interaction, ripple(color = Color.White), enabled = enabled, role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .then(if (enabled) Modifier else Modifier.background(Color.White.copy(alpha = 0.35f))),
        contentAlignment = Alignment.Center,
    ) {
        if (content != null) {
            content()
        } else {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (icon != null) Icon(icon, null, tint = Color.White, modifier = Modifier.size(if (hero) 24.dp else 20.dp))
                Text(
                    text,
                    style = TideType.rounded(if (hero) 20.sp else 17.sp, FontWeight.Bold),
                    color = Color.White,
                    maxLines = 1,
                )
            }
        }
    }
}

/** Quiet text button: a secondary action under a CTA. */
@Composable
fun QuietButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, color: Color = Tide.ink2, icon: ImageVector? = null, tag: String? = null) {
    Row(
        modifier
            .clip(RoundedCornerShape(12.dp))
            .clickable(role = Role.Button, onClick = onClick)
            .heightIn(min = 44.dp)
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (icon != null) Icon(icon, null, tint = color, modifier = Modifier.size(18.dp))
        Text(text, style = TideType.rounded(15.sp, FontWeight.Bold), color = color, textAlign = TextAlign.Center)
    }
}

@Composable
fun SectionLabel(text: String, modifier: Modifier = Modifier) {
    Text(text.uppercase(), style = TideType.sectionLabel, modifier = modifier)
}

/** A symbol in a pale aqua disc, the app's recurring hero mark. */
@Composable
fun SymbolDisc(icon: ImageVector, size: Dp = 132.dp, iconSize: Dp = 52.dp, fill: Color = Tide.aquaTint, tint: Color = Tide.aqua) {
    Box(Modifier.size(size).background(fill, CircleShape), contentAlignment = Alignment.Center) {
        Icon(icon, null, tint = tint, modifier = Modifier.size(iconSize))
    }
}

/** A tappable info card with a leading icon and a chevron (the iOS check-in and unlock rows). */
@Composable
fun ChevronCard(
    icon: ImageVector,
    title: String?,
    detail: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tag: String? = null,
) {
    Row(
        modifier
            .fillMaxWidth()
            .tideCard(18.dp)
            .clickable(role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, null, tint = Tide.aqua, modifier = Modifier.size(20.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            if (title != null) Text(title, style = TideType.subheadline.copy(fontWeight = FontWeight.SemiBold, color = Tide.ink))
            Text(detail, style = if (title != null) TideType.caption2 else TideType.caption)
        }
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Tide.ink3, modifier = Modifier.size(20.dp))
    }
}

/** A note with a small leading icon and no card (the troubleshooting and safety lines). */
@Composable
fun IconNote(icon: ImageVector, text: String, modifier: Modifier = Modifier, tint: Color = Tide.ink3, inCard: Boolean = false) {
    Row(
        modifier.fillMaxWidth().then(if (inCard) Modifier.tideCard(18.dp).padding(14.dp) else Modifier),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(icon, null, tint = tint, modifier = Modifier.padding(top = 1.dp).size(16.dp))
        Text(text, style = TideType.caption.copy(color = if (inCard) Tide.ink2 else Tide.ink3))
    }
}

/** Milliseconds since first composition, advanced every frame. */
@Composable
fun rememberFrameClock(): Long {
    var now by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { now = it - start }
    }
    return now
}

/** Expanding ripple, the app's visual signature; mirrors the icon. */
@Composable
fun RipplePulse(intervalSeconds: Double, color: Color, modifier: Modifier = Modifier) {
    val period = (intervalSeconds * 1000).toInt().coerceAtLeast(200)
    val transition = rememberInfiniteTransition(label = "ripple")
    val phase by transition.animateFloat(0f, 1f, infiniteRepeatable(tween(period, easing = LinearEasing)), label = "phase")
    Canvas(modifier) {
        val maxRadius = size.minDimension / 2
        for (i in 0 until 3) {
            val p = (phase + i / 3f) % 1f
            drawCircle(color.copy(alpha = 0.55f * (1 - p)), radius = maxRadius * (0.25f + p * 0.75f) - 1.5.dp.toPx(), style = Stroke(3.dp.toPx()))
        }
        drawCircle(color, radius = 9.dp.toPx())
    }
}

/**
 * The breathing pacer: a circle that opens on the in-breath and settles on the
 * out-breath, driven by wall-clock time so it stays in step with the vibration.
 */
@Composable
fun BreathingBloom(pattern: BreathePattern, anchorMillis: Long?, modifier: Modifier = Modifier, showsLabel: Boolean = true) {
    val frame = rememberFrameClock()
    // Reading `frame` keeps this recomposing every frame; the anchor keeps it on the session's clock.
    val elapsed = if (anchorMillis != null) frame.let { System.currentTimeMillis() - anchorMillis } else frame
    val phase = BreathPhase.at(elapsed, pattern)
    Box(modifier, contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val side = size.minDimension
            val center = Offset(size.width / 2, size.height / 2)
            drawCircle(Tide.paper3, radius = side * 0.46f, center = center, style = Stroke(6.dp.toPx()))
            val r = side * phase.scale / 2
            drawCircle(Tide.aquaTint, radius = r, center = center)
            drawCircle(Tide.aqua.copy(alpha = 0.8f), radius = r, center = center, style = Stroke(3.dp.toPx()))
        }
        if (showsLabel) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(if (phase.isInhale) "In" else "Out", style = TideType.rounded(20.sp, FontWeight.Bold), color = Tide.ink)
                Text("${phase.secondsLeft}", style = TideType.rounded(15.sp, FontWeight.Medium), color = Tide.ink3)
            }
        }
    }
}

/** A progress ring: the intensity dial and the Press hold timer. */
@Composable
fun ProgressRing(fraction: Float, modifier: Modifier = Modifier, lineWidth: Dp = 10.dp, content: @Composable BoxScope.() -> Unit = {}) {
    Box(modifier, contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val stroke = lineWidth.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(Tide.paper3, 0f, 360f, false, topLeft = Offset(inset, inset), size = arcSize, style = Stroke(stroke))
            drawArc(
                Tide.aqua, -90f, 360f * fraction.coerceIn(0f, 1f), false,
                topLeft = Offset(inset, inset), size = arcSize, style = Stroke(stroke, cap = StrokeCap.Round),
            )
        }
        content()
    }
}

@Composable
fun Gap(height: Dp) = Spacer(Modifier.height(height))

@Composable
fun HGap(width: Dp) = Spacer(Modifier.width(width))
