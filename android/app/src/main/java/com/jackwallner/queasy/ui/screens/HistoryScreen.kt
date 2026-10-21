package com.jackwallner.queasy.ui.screens

import android.content.Intent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import com.jackwallner.queasy.Overlay
import com.jackwallner.queasy.model.EpisodeSource
import com.jackwallner.queasy.model.EpisodeStats
import com.jackwallner.queasy.model.FreeTier
import com.jackwallner.queasy.model.ReliefEpisode
import com.jackwallner.queasy.model.ReliefMode
import com.jackwallner.queasy.ui.LocalGraph
import com.jackwallner.queasy.ui.TideTopBar
import com.jackwallner.queasy.ui.theme.ChevronCard
import com.jackwallner.queasy.ui.theme.Tide
import com.jackwallner.queasy.ui.theme.TideType
import com.jackwallner.queasy.ui.theme.icon
import com.jackwallner.queasy.ui.theme.tideCard
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.WeekFields
import java.util.Locale

/** Free history is a window, not a sample: the last week whole, older sessions are what Pro buys back. */
fun visibleEpisodes(all: List<ReliefEpisode>, isPro: Boolean, now: Instant = Instant.now()): List<ReliefEpisode> {
    if (isPro) return all
    val cutoff = now.minusSeconds(FreeTier.HISTORY_DAYS * 86_400L)
    return all.filter { !it.startedAt.isBefore(cutoff) }
}

/** Doctor-shareable log, one row per session, oldest first; the iOS columns exactly. */
fun historyCsv(episodes: List<ReliefEpisode>): String {
    val iso = DateTimeFormatter.ISO_INSTANT
    val rows = episodes.sortedBy { it.startedAt }.map { e ->
        listOf(
            iso.format(e.startedAt.truncatedTo(java.time.temporal.ChronoUnit.SECONDS)),
            e.endedAt?.let { iso.format(it.truncatedTo(java.time.temporal.ChronoUnit.SECONDS)) } ?: "",
            e.cause.raw,
            "${e.severityBefore}",
            e.severityAfter?.toString() ?: "",
            "${e.intensity}",
            "${e.plannedMinutes}",
            e.source.raw,
        ).joinToString(",")
    }
    return (listOf("started_at,ended_at,cause,severity_before,severity_after,intensity,planned_minutes,source") + rows).joinToString("\n")
}

/** `HistoryView.swift`. */
@Composable
fun HistoryScreen() {
    val graph = LocalGraph.current
    val context = LocalContext.current
    val all = graph.episodes.episodes
    val visible = visibleEpisodes(all, graph.subscriptions.isPro)
    val hidden = all.size - visible.size
    var toDelete by remember { mutableStateOf<ReliefEpisode?>(null) }

    Column(Modifier.fillMaxSize().background(Tide.tideWash)) {
        TideTopBar("History", trailing = {
            if (all.isNotEmpty()) {
                IconButton(onClick = {
                    val dir = File(context.cacheDir, "exports").apply { mkdirs() }
                    val file = File(dir, "Queasy-History.csv").apply { writeText(historyCsv(all)) }
                    val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
                    val send = Intent(Intent.ACTION_SEND).setType("text/csv").putExtra(Intent.EXTRA_STREAM, uri)
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    context.startActivity(Intent.createChooser(send, "Export history"))
                }, modifier = Modifier.semantics { contentDescription = "Export history as CSV" }.testTag("history-export")) {
                    Icon(Icons.Rounded.Share, null, tint = Tide.aqua)
                }
            }
        })
        if (all.isEmpty()) {
            EmptyState()
        } else {
            val entries = visible.map { it.toEntry() }
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 18.dp, end = 18.dp, bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                item { StatsHeader(EpisodeStats.summarize(entries)) }
                if (graph.settings.showHistoryHeatmap) item { HeatmapCard(EpisodeStats.heatmap(entries)) }
                items(visible, key = { it.uuid }) { episode -> EpisodeRow(episode) { toDelete = episode } }
                if (hidden > 0) {
                    item {
                        ChevronCard(
                            icon = Icons.Rounded.History,
                            title = "$hidden older ${if (hidden == 1) "session" else "sessions"}",
                            detail = "Still saved on this phone. Pro shows everything past the last ${FreeTier.HISTORY_DAYS} days.",
                            onClick = { graph.navigator.push(Overlay.Paywall("queasy_history")) },
                            tag = "history-unlock",
                        )
                    }
                }
                item {
                    Text("Touch and hold a session to delete it.", style = TideType.caption2, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                }
            }
        }
    }

    toDelete?.let { episode ->
        AlertDialog(
            onDismissRequest = { toDelete = null },
            title = { Text("Delete this session?") },
            text = { Text("This removes the session from your history permanently.") },
            confirmButton = {
                TextButton(onClick = {
                    graph.episodes.delete(episode.uuid)
                    toDelete = null
                }, modifier = Modifier.testTag("confirm-delete")) { Text("Delete", color = Tide.coral) }
            },
            dismissButton = { TextButton(onClick = { toDelete = null }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun EmptyState() {
    Column(
        Modifier.fillMaxSize().padding(horizontal = 40.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(Icons.Rounded.History, null, tint = Tide.ink3, modifier = Modifier.size(42.dp))
        Text("No sessions yet", style = TideType.headline.copy(color = Tide.ink2))
        Text(
            "Run your first comfort session and it will show up here with how you felt afterward.",
            style = TideType.subheadline.copy(color = Tide.ink3),
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun StatsHeader(summary: EpisodeStats.Summary) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatTile(summary.averageReliefDelta?.let { "%+.1f".format(Locale.US, -it) } ?: "n/a", "avg severity\nchange", Modifier.weight(1f))
        StatTile("${summary.sessionsThisWeek}", "sessions\nthis week", Modifier.weight(1f))
        StatTile(summary.bestMode?.title ?: "n/a", "mode that\nhelps most", Modifier.weight(1f))
    }
}

@Composable
private fun StatTile(value: String, label: String, modifier: Modifier) {
    Column(
        modifier.tideCard(18.dp).padding(vertical = 14.dp, horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(value, style = TideType.rounded(22.sp, FontWeight.Bold), color = Tide.ink, maxLines = 1)
        Text(label, style = TideType.caption2.copy(color = Tide.ink2), textAlign = TextAlign.Center)
    }
}

@Composable
private fun HeatmapCard(days: List<EpisodeStats.HeatmapDay>) {
    val queasy = days.count { it.count > 0 }
    val calm = days.size - queasy
    Column(Modifier.fillMaxWidth().tideCard(18.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Last ${days.size} days", style = TideType.caption.copy(fontWeight = FontWeight.SemiBold))
        HeatmapGrid(days)
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Text("$queasy ${if (queasy == 1) "queasy day" else "queasy days"}", style = TideType.caption)
            Text("$calm ${if (calm == 1) "calm day" else "calm days"}", style = TideType.caption)
        }
    }
}

/** Columns are weeks, rows are weekdays from the locale's first day; aqua deepens with the day's worst severity. */
@Composable
private fun HeatmapGrid(days: List<EpisodeStats.HeatmapDay>) {
    val first = days.firstOrNull() ?: return
    val firstDayOfWeek = WeekFields.of(Locale.getDefault()).firstDayOfWeek
    val lead = (first.date.dayOfWeek.value - firstDayOfWeek.value + 7) % 7
    val cells: List<EpisodeStats.HeatmapDay?> = List(lead) { null } + days
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        cells.chunked(7).forEach { column ->
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                column.forEach { day ->
                    val color = when {
                        day == null -> Color.Transparent
                        day.count == 0 -> Tide.ink.copy(alpha = 0.07f)
                        (day.peakSeverity ?: 1) <= 2 -> Tide.aqua.copy(alpha = 0.4f)
                        day.peakSeverity == 3 -> Tide.aqua.copy(alpha = 0.7f)
                        else -> Tide.aqua
                    }
                    Box(Modifier.size(13.dp).background(color, RoundedCornerShape(3.dp)))
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun EpisodeRow(episode: ReliefEpisode, onLongPress: () -> Unit) {
    val formatter = remember { DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT).withZone(ZoneId.systemDefault()) }
    Row(
        Modifier
            .fillMaxWidth()
            .tideCard(16.dp)
            .combinedClickable(onClick = {}, onLongClick = onLongPress, onLongClickLabel = "Delete session")
            .testTag("episode-row")
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(34.dp).background(Tide.aquaTint, CircleShape), contentAlignment = Alignment.Center) {
            Icon(episode.mode.icon, null, tint = Tide.aqua, modifier = Modifier.size(18.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                "${episode.mode.title} · ${episode.cause.label}",
                style = TideType.subheadline.copy(fontWeight = FontWeight.SemiBold, color = Tide.ink),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            val detail = if (episode.mode == ReliefMode.PULSE) "Level ${episode.intensity}" else "${episode.plannedMinutes} min"
            val source = if (episode.source == EpisodeSource.WATCH) "Watch" else "Phone"
            Text("${formatter.format(episode.startedAt)} · $detail · $source", style = TideType.caption)
        }
        DeltaBadge(episode.reliefDelta)
    }
}

@Composable
private fun DeltaBadge(delta: Int?) {
    if (delta == null) {
        Text("unrated", style = TideType.caption2)
        return
    }
    val (text, fg, bg) = when {
        delta > 0 -> Triple("−$delta", Tide.aqua, Tide.aquaTint)
        delta == 0 -> Triple("±0", Tide.ink3, Tide.paper3)
        else -> Triple("+${-delta}", Tide.coral, Tide.coralTint)
    }
    Text(
        text,
        style = TideType.rounded(14.sp, FontWeight.Bold),
        color = fg,
        modifier = Modifier.background(bg, CircleShape).padding(horizontal = 10.dp, vertical = 5.dp),
    )
}
