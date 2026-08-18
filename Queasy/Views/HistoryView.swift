import SwiftData
import SwiftUI
import UIKit

struct HistoryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReliefEpisode.startedAt, order: .reverse) private var episodes: [ReliefEpisode]
    @State private var episodeToDelete: ReliefEpisode?
    @State private var exportURL: URL?
    @State private var showPaywall = false

    /// Free history is a window, not a sample: the last week is kept whole, and
    /// anything older is what Pro buys back. Nothing is deleted either way.
    private var visibleEpisodes: [ReliefEpisode] {
        guard !subscriptions.isProSubscriber else { return episodes }
        let cutoff = Calendar.current.date(byAdding: .day, value: -FreeTier.historyDays, to: .now) ?? .distantPast
        return episodes.filter { $0.startedAt >= cutoff }
    }

    private var hiddenEpisodeCount: Int { episodes.count - visibleEpisodes.count }

    var body: some View {
        NavigationStack {
            Group {
                if episodes.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .tideBackground()
            .tideNavigationTitle("History")
            .toolbar {
                if !episodes.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            exportURL = writeCSV()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Theme.aqua)
                        }
                        .accessibilityLabel("Export history as CSV")
                    }
                }
            }
            .sheet(item: $exportURL) { url in
                ActivityShareSheet(items: [url])
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(displayCloseButton: true, paywallImpressionId: "queasy_history")
            }
            .confirmationDialog(
                "Delete this session?",
                isPresented: Binding(
                    get: { episodeToDelete != nil },
                    set: { if !$0 { episodeToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let episode = episodeToDelete {
                        modelContext.delete(episode)
                        try? modelContext.save()
                    }
                    episodeToDelete = nil
                }
                Button("Cancel", role: .cancel) { episodeToDelete = nil }
            } message: {
                Text("This removes the session from your history permanently.")
            }
        }
    }

    private var entries: [EpisodeStats.Entry] {
        visibleEpisodes.map {
            EpisodeStats.Entry(
                startedAt: $0.startedAt,
                cause: $0.cause,
                mode: $0.mode,
                severityBefore: $0.severityBefore,
                severityAfter: $0.severityAfter
            )
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsHeader
                if settings.showHistoryHeatmap {
                    heatmapCard
                }
                LazyVStack(spacing: 10) {
                    ForEach(visibleEpisodes) { episode in
                        EpisodeRow(episode: episode)
                            .contextMenu {
                                Button(role: .destructive) {
                                    episodeToDelete = episode
                                } label: {
                                    Label("Delete Session", systemImage: "trash")
                                }
                            }
                    }
                }
                if hiddenEpisodeCount > 0 {
                    olderSessionsCard
                }
                Text("Touch and hold a session to delete it.")
                    .font(.caption2)
                    .foregroundStyle(Theme.ink3)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private var statsHeader: some View {
        let summary = EpisodeStats.summarize(entries)
        return HStack(spacing: 10) {
            statTile(
                value: summary.averageReliefDelta.map { String(format: "%+.1f", -$0) } ?? "n/a",
                label: "avg severity\nchange"
            )
            statTile(value: "\(summary.sessionsThisWeek)", label: "sessions\nthis week")
            statTile(value: summary.bestMode?.title ?? "n/a", label: "mode that\nhelps most")
        }
    }

    /// Everything older than the free window is still stored; this is the row
    /// that says so, rather than quietly pretending those sessions never
    /// happened.
    private var olderSessionsCard: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.aqua)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(hiddenEpisodeCount) older \(hiddenEpisodeCount == 1 ? "session" : "sessions")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Still saved on your iPhone. Pro shows everything past the last \(FreeTier.historyDays) days.")
                        .font(.caption2)
                        .foregroundStyle(Theme.ink3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(14)
            .tideCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history-unlock")
    }

    // MARK: - Heatmap (the "queasy log" at a glance)

    private var heatmapCard: some View {
        let days = EpisodeStats.heatmap(entries)
        let queasyDays = days.filter { $0.count > 0 }.count
        let calmDays = days.count - queasyDays
        return VStack(alignment: .leading, spacing: 12) {
            Text("Last \(days.count) days")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink2)
            EpisodeHeatmapGrid(days: days)
            HStack(spacing: 14) {
                summaryChip(value: queasyDays, label: queasyDays == 1 ? "queasy day" : "queasy days")
                summaryChip(value: calmDays, label: calmDays == 1 ? "calm day" : "calm days")
                Spacer(minLength: 0)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.ink2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tideCard(cornerRadius: 18)
    }

    private func summaryChip(value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)").fontWeight(.semibold).foregroundStyle(Theme.ink)
            Text(label)
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.roundedNumeric(22, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .tideCard(cornerRadius: 18)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 42))
                .foregroundStyle(Theme.ink3)
            Text("No sessions yet")
                .font(.headline)
                .foregroundStyle(Theme.ink2)
            Text("Run your first comfort session and it will show up here with how you felt afterward.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - CSV export

    /// Doctor-shareable log: one row per session.
    private func writeCSV() -> URL? {
        var lines = ["started_at,ended_at,cause,severity_before,severity_after,intensity,planned_minutes,source"]
        let iso = ISO8601DateFormatter()
        for e in episodes.sorted(by: { $0.startedAt < $1.startedAt }) {
            lines.append([
                iso.string(from: e.startedAt),
                e.endedAt.map(iso.string(from:)) ?? "",
                e.cause.rawValue,
                "\(e.severityBefore)",
                e.severityAfter.map(String.init) ?? "",
                "\(e.intensity)",
                "\(e.plannedMinutes)",
                e.source.rawValue,
            ].joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Queasy-History.csv")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// GitHub-style day grid: columns are weeks, rows are weekdays. Aqua deepens
/// with that day's worst check-in severity.
private struct EpisodeHeatmapGrid: View {
    let days: [EpisodeStats.HeatmapDay]
    var cellSize: CGFloat = 13
    var cellSpacing: CGFloat = 3

    private var columns: [[EpisodeStats.HeatmapDay?]] {
        guard let first = days.first else { return [] }
        let leadingPad = Calendar.current.component(.weekday, from: first.date) - 1
        var cells: [EpisodeStats.HeatmapDay?] = Array(repeating: nil, count: leadingPad)
        cells.append(contentsOf: days.map { Optional($0) })
        var out: [[EpisodeStats.HeatmapDay?]] = []
        var current: [EpisodeStats.HeatmapDay?] = []
        for cell in cells {
            current.append(cell)
            if current.count == 7 {
                out.append(current)
                current = []
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                    VStack(spacing: cellSpacing) {
                        ForEach(Array(col.enumerated()), id: \.offset) { _, day in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: day))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    private func color(for day: EpisodeStats.HeatmapDay?) -> Color {
        guard let day else { return .clear }
        guard day.count > 0 else { return Theme.ink.opacity(0.07) }
        switch day.peakSeverity ?? 1 {
        case ...2: return Theme.aqua.opacity(0.4)
        case 3: return Theme.aqua.opacity(0.7)
        default: return Theme.aqua
        }
    }
}

/// Plain UIKit share sheet — ShareLink can't lazily produce the CSV file.
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct EpisodeRow: View {
    let episode: ReliefEpisode

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: episode.mode.symbolName)
                .font(.body)
                .foregroundStyle(Theme.aqua)
                .frame(width: 34, height: 34)
                .background(Theme.aquaTint, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(episode.mode.title) · \(episode.cause.label)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("\(episode.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(detailLabel) · \(sourceLabel)")
                    .font(.caption)
                    .foregroundStyle(Theme.ink2)
            }

            Spacer()

            deltaBadge
        }
        .padding(14)
        .tideCard(cornerRadius: 16)
    }

    private var sourceLabel: String {
        episode.source == .watch ? "Watch" : "iPhone"
    }

    /// Level only means something for Pulse; the other modes report length.
    private var detailLabel: String {
        episode.mode == .pulse ? "Level \(episode.intensity)" : "\(episode.plannedMinutes) min"
    }

    @ViewBuilder
    private var deltaBadge: some View {
        if let delta = episode.reliefDelta {
            Text(delta > 0 ? "−\(delta)" : (delta == 0 ? "±0" : "+\(-delta)"))
                .font(Theme.roundedNumeric(14, weight: .bold))
                .foregroundStyle(delta > 0 ? Theme.aqua : (delta == 0 ? Theme.ink3 : Theme.coral))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    delta > 0 ? Theme.aquaTint : (delta == 0 ? Theme.paper3 : Theme.coralTint),
                    in: Capsule()
                )
        } else {
            Text("unrated")
                .font(.caption2)
                .foregroundStyle(Theme.ink3)
        }
    }
}
