import SwiftUI

struct RelieveHomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = PhoneSessionController.shared
    @State private var watch = WatchAvailability.shared
    @State private var watchSession = WatchSessionMirror.shared
    @State private var showCheckIn = false
    @State private var showSession = false
    @State private var showWatchSession = false
    @State private var sheetMode: ReliefMode?
    @State private var watchFeedback: String?

    /// Quick start reuses the last plan when there is one, otherwise the
    /// evergreen default (Pulse, level 5, 15 min).
    private var quickPlan: ReliefPlan {
        settings.lastPlan ?? .quickStart
    }

    private var quickMode: ReliefMode { quickPlan.mode }

    private var quickSeconds: Int {
        switch quickMode {
        case .tone: return 60
        case .press: return PressProtocol.holdSeconds
        case .pulse, .breathe:
            return FreeTier.cappedSeconds(
                for: quickMode,
                requested: quickPlan.durationMinutes * 60,
                isPro: subscriptions.isProSubscriber
            )
        }
    }

    #if DEBUG
    /// Marketing capture: the sim has no paired watch, force the watch-primary
    /// layout so the hero shot shows the core pitch.
    private var isScreenshotRun: Bool {
        ProcessInfo.processInfo.arguments.contains("-QueasyScreenshots")
    }
    #else
    private var isScreenshotRun: Bool { false }
    #endif

    /// Watch-first whenever a watch is paired at all. We deliberately do NOT
    /// gate on `isWatchAppInstalled`: that flag is slow and unreliable to sync,
    /// and reading it wrong stranded people on the phone-only layout even with
    /// Queasy installed on their wrist. Offer the wrist, attempt the launch, and
    /// let the troubleshooting note cover the rare not-installed / no-perms case.
    private var showsWatchPrimary: Bool {
        watch.isPaired || isScreenshotRun
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    if controller.phase != .idle {
                        activeSessionCard
                    }
                    if watchSession.isRunning {
                        watchActiveSessionCard
                    }

                    quickStartCard
                    checkInButton
                    modeGrid

                    if showsWatchPrimary {
                        wearHintCard
                        if !isScreenshotRun {
                            watchTroubleshootNote
                        }
                    } else if !isScreenshotRun {
                        builtForWatchCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
            .tideBackground()
            .tideNavigationTitle("Queasy")
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { watch.refresh() }
            }
            .task {
                #if DEBUG
                // Marketing capture of the wrist-session control surface.
                if ProcessInfo.processInfo.arguments.contains("-QueasyWatchSessionScreenshot") {
                    watchSession.seedScreenshotSession()
                    try? await Task.sleep(for: .milliseconds(300))
                    showWatchSession = true
                }
                await openDebugScreen()
                #endif
            }
            .sheet(isPresented: $showCheckIn) {
                CheckInView { plan in
                    settings.lastPlan = plan
                }
            }
            .sheet(item: $sheetMode) { mode in
                ModeStartView(mode: mode) { plan in
                    settings.lastPlan = plan
                }
            }
            .fullScreenCover(isPresented: $showSession) {
                PhoneSessionView()
            }
            .fullScreenCover(isPresented: $showWatchSession) {
                WatchRemoteSessionView()
            }
            // A phone session can start from inside a sheet; present the session
            // UI from here once the sheet is out of the way.
            .onChange(of: controller.phase) { _, phase in
                if phase == .running {
                    showCheckIn = false
                    sheetMode = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        showSession = true
                    }
                }
            }
            // Watch confirmed the session the phone just asked for: open the
            // remote controls so the whole thing is drivable from the phone.
            .onChange(of: watchSession.phase) { _, phase in
                if phase == .running { settings.hasConfirmedWatchSession = true }
                if phase == .running, watchSession.pendingAutoPresent {
                    watchSession.pendingAutoPresent = false
                    showCheckIn = false
                    sheetMode = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        showWatchSession = true
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Feeling queasy?")
                .font(Theme.displaySerif(30))
                .foregroundStyle(Theme.ink)
            Text("Four drug-free things to try, on your wrist or in your ear. Start one now, or answer three questions first.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Quick start (the fast path: one tap, no questions)

    private var quickStartCard: some View {
        VStack(spacing: 12) {
            if quickMode == .breathe {
                BreathingBloom(pattern: quickPlan.breathe, showsLabel: false)
                    .frame(height: 96)
            } else {
                RipplePulseView(interval: 1.4, color: Theme.aqua)
                    .frame(height: 96)
            }

            Button {
                startQuick()
            } label: {
                Label(quickTitle, systemImage: quickMode.symbolName)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Theme.ctaGradient, in: RoundedRectangle(cornerRadius: Theme.ctaRadius))
                    .shadow(color: Theme.aqua.opacity(0.35), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("quick-start")

            Text(quickCaption)
                .font(.footnote)
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)

            if let watchFeedback {
                Label(watchFeedback, systemImage: "applewatch")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.aquaDeep)
                    .transition(.opacity)
            }

            if showsWatchPrimary, quickMode.runsOnWatch {
                Button {
                    startQuickOnPhone()
                } label: {
                    Text("Use iPhone instead")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink2)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quick-start-phone")
            }
        }
        .padding(Theme.cardPadding)
        .tideCard()
    }

    private var quickTitle: String {
        switch quickMode {
        case .pulse: return "Start the Pulse"
        case .breathe: return "Start Breathing"
        case .tone: return "Play the Tone"
        case .press: return "Start the Hold"
        }
    }

    private var quickCaption: String {
        let where_ = (showsWatchPrimary && quickMode.runsOnWatch) ? "on your wrist" : "on this iPhone"
        switch quickMode {
        case .tone: return "100 Hz, one minute, headphones in"
        case .press: return "\(PressProtocol.holdSeconds / 60) minutes of steady pressure, timed"
        case .pulse: return "Level \(quickPlan.intensity) · \(quickSeconds / 60) min \(where_)"
        case .breathe: return "\(quickPlan.breathe.label) · \(quickSeconds / 60) min \(where_)"
        }
    }

    // MARK: - Mode grid

    private var modeGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
            spacing: 12
        ) {
            ForEach(ReliefMode.allCases) { mode in
                Button {
                    sheetMode = mode
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: mode.symbolName)
                            .font(.title3)
                            .foregroundStyle(Theme.aqua)
                        Text(mode.title)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text(mode.tagline)
                            .font(.caption2)
                            .foregroundStyle(Theme.ink3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
                    .padding(14)
                    .tideCard(cornerRadius: 20)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mode-card-\(mode.rawValue)")
            }
        }
    }

    private var checkInButton: some View {
        Button {
            showCheckIn = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.aqua)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Match to my symptoms")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Three questions pick the mode, level and length for you.")
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
        .accessibilityIdentifier("start-checkin")
    }

    #if DEBUG
    /// Jump straight to a screen for capture and review, since a headless
    /// simulator can be launched but not tapped. `-QueasyScreen <name>` with
    /// name in: mode-pulse, mode-breathe, mode-tone, mode-press, checkin,
    /// session-pulse, session-breathe, session-press.
    private func openDebugScreen() async {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-QueasyScreen"), args.indices.contains(flag + 1) else { return }
        let screen = args[flag + 1]
        try? await Task.sleep(for: .milliseconds(400))

        if screen == "checkin" || screen.hasPrefix("recommend-") {
            showCheckIn = true
            return
        }
        if screen.hasPrefix("mode-"), let mode = ReliefMode(rawValue: String(screen.dropFirst(5))) {
            sheetMode = mode
            return
        }
        if screen.hasPrefix("session-"), let mode = ReliefMode(rawValue: String(screen.dropFirst(8))) {
            var plan = ReliefPlan.quickStart(mode: mode)
            plan.breathe = .relaxed
            PhoneSessionController.shared.start(plan: plan, seconds: FreeTier.sessionSeconds)
        }
    }
    #endif

    // MARK: - Starting

    private func startQuick() {
        if showsWatchPrimary, quickMode.runsOnWatch {
            startOnWatch()
        } else {
            startQuickOnPhone()
        }
    }

    private func startOnWatch() {
        var plan = quickPlan
        plan.durationMinutes = max(quickSeconds / 60, 1)
        settings.lastPlan = plan
        // Extended Runtime sessions start on the watch, so first-time users may
        // need to open Queasy there before the phone can show live controls.
        let firstTime = !settings.hasConfirmedWatchSession
        Task {
            let outcome = await WatchLauncher.shared.startOnWatch(plan: plan)
            withAnimation {
                if firstTime, outcome == .queued {
                    watchFeedback = "Open Queasy on your Apple Watch to start this wrist session."
                } else {
                    watchFeedback = outcome == .started
                        ? "Starting on your watch…"
                        : "Sent. Open Queasy on your watch."
                }
            }
            try? await Task.sleep(for: .seconds(firstTime ? 7 : 4))
            withAnimation { watchFeedback = nil }
        }
    }

    private func startQuickOnPhone() {
        PhoneSessionController.shared.start(plan: quickPlan, seconds: quickSeconds)
        showSession = true
    }

    // MARK: - Active sessions

    private var activeSessionCard: some View {
        Button {
            showSession = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(Theme.aqua)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.phase == .running ? "\(controller.mode.title) running" : "How do you feel?")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("\(controller.remainingSeconds / 60):\(String(format: "%02d", controller.remainingSeconds % 60)) left")
                        .font(.caption)
                        .foregroundStyle(Theme.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(16)
            .tideCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }

    /// A session is running on the wrist: tap to control or end it from here.
    private var watchActiveSessionCard: some View {
        Button {
            showWatchSession = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundStyle(Theme.aqua)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Running on your watch")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Level \(watchSession.intensity) · \(max(Int(watchSession.endsAt.timeIntervalSinceNow) / 60, 0)) min left · tap to control")
                        .font(.caption)
                        .foregroundStyle(Theme.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(16)
            .tideCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("watch-session-card")
    }

    // MARK: - Info cards

    /// Quiet catch-all for the thing that most often keeps a wrist session from
    /// being felt: Queasy not installed or not opened on the watch yet.
    private var watchTroubleshootNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.footnote)
                .foregroundStyle(Theme.ink3)
                .padding(.top, 1)
            Text("Not feeling anything on your wrist? Open Queasy on your Apple Watch once to finish installing it and start the wrist session.")
                .font(.caption)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    /// No watch paired: keep the fallback honest; the wrist is the product.
    private var builtForWatchCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.title3)
                .foregroundStyle(Theme.aqua)
            Text("Queasy is built for Apple Watch: sessions you feel on your wrist that keep running with the screen off. On iPhone they run through the phone's own vibration instead, so rest it against you.")
                .font(.caption)
                .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tideCard(cornerRadius: 18)
    }

    private var wearHintCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "applewatch.side.right")
                .font(.title3)
                .foregroundStyle(Theme.ink2)
            Text("For Pulse and Press, turn your watch to the **inside** of your wrist, three finger-widths below the crease. That is where an acupressure band sits.")
                .font(.caption)
                .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tideCard(cornerRadius: 18)
    }
}

/// Expanding ripple animation, the app's visual signature; mirrors the icon.
struct RipplePulseView: View {
    var interval: Double
    var color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: interval)) / interval
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let p = (phase + Double(i) / 3.0).truncatingRemainder(dividingBy: 1.0)
                    Circle()
                        .stroke(color.opacity(0.55 * (1 - p)), lineWidth: 3)
                        .scaleEffect(0.25 + p * 0.75)
                }
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
            }
        }
    }
}
