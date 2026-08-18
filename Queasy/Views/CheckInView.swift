import SwiftUI

/// The 3-question check-in, ending on the recommendation screen.
struct CheckInView: View {
    /// Called with the final plan when the user starts (on either device).
    var onPlanReady: (ReliefPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cause: NauseaCause?
    @State private var severity: Int?
    @State private var stillExposed: Bool?
    @State private var recentlyAte: Bool?
    @State private var step = 0

    #if DEBUG
    /// `-QueasyScreen recommend-<cause>` lands straight on the recommendation
    /// so the mode picker can be reviewed on a simulator that cannot be tapped.
    private static var debugPrefill: (NauseaCause, Int)? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-QueasyScreen"), args.indices.contains(flag + 1) else { return nil }
        let screen = args[flag + 1]
        guard screen.hasPrefix("recommend-"),
              let cause = NauseaCause(rawValue: String(screen.dropFirst("recommend-".count)))
        else { return nil }
        return (cause, 4)
    }
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: 4)
                    .tint(Theme.aqua)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                TabView(selection: $step) {
                    causeStep.tag(0)
                    severityStep.tag(1)
                    contextStep.tag(2)
                    recommendationStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
            .tideBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.ink2)
                }
            }
            .task {
                #if DEBUG
                if let (prefillCause, prefillSeverity) = Self.debugPrefill {
                    cause = prefillCause
                    severity = prefillSeverity
                    stillExposed = true
                    recentlyAte = false
                    step = 3
                }
                #endif
            }
        }
    }

    // MARK: - Step 1: cause

    private var causeStep: some View {
        VStack(spacing: 16) {
            stepTitle("What kind of queasy?")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                ForEach(NauseaCause.allCases) { candidate in
                    Button {
                        cause = candidate
                        withAnimation { step = 1 }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: candidate.symbolName)
                                .font(.title2)
                                .foregroundStyle(cause == candidate ? .white : Theme.aqua)
                            Text(candidate.label)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(cause == candidate ? .white : Theme.ink)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 92)
                        .background(
                            cause == candidate ? Theme.aqua : Theme.paper2,
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cause-\(candidate.rawValue)")
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .padding(.top, 22)
    }

    // MARK: - Step 2: severity

    private var severityStep: some View {
        VStack(spacing: 16) {
            stepTitle("How bad is it right now?")
            VStack(spacing: 10) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        severity = level
                        withAnimation { step = 2 }
                    } label: {
                        HStack {
                            Text("\(level)")
                                .font(Theme.roundedNumeric(20, weight: .bold))
                                .foregroundStyle(severity == level ? .white : Theme.severityColor(level))
                                .frame(width: 34)
                            Text(Self.severityLabels[level - 1])
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(severity == level ? .white : Theme.ink)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(
                            severity == level ? Theme.severityColor(level) : Theme.paper2,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("severity-\(level)")
                }
            }
            .padding(.horizontal, 20)
            Spacer()
        }
        .padding(.top, 22)
    }

    static let severityLabels = [
        "Barely there",
        "Noticeable",
        "Uncomfortable",
        "Really rough",
        "About to be sick",
    ]

    // MARK: - Step 3: context
    //
    // Two quick taps, tailored to the cause. No toggles, no submit: answering
    // the second question advances straight to the recommendation, same feel
    // as the cause and severity steps.

    private var contextStep: some View {
        VStack(spacing: 22) {
            stepTitle("Two quick things")

            VStack(spacing: 20) {
                contextQuestion(
                    prompt: exposureQuestion.prompt,
                    detail: exposureQuestion.detail,
                    selection: stillExposed,
                    idPrefix: "exposed"
                ) { answer in
                    stillExposed = answer
                    advanceIfComplete()
                }

                contextQuestion(
                    prompt: "Eaten in the last hour?",
                    detail: "We start gentler on a full stomach.",
                    selection: recentlyAte,
                    idPrefix: "ate"
                ) { answer in
                    recentlyAte = answer
                    advanceIfComplete()
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.top, 22)
    }

    /// The "is it still happening" question, worded for the chosen cause.
    private var exposureQuestion: (prompt: String, detail: String) {
        switch cause {
        case .motion:
            return ("Still moving?", "In the car, on the boat, or in the air right now.")
        case .morningSickness:
            return ("Mid-wave?", "Right in it, or on the way back down.")
        case .hangover:
            return ("Still feeling rough?", "At the peak, or on the way down.")
        case .vertigo:
            return ("Still spinning?", "Room still moving, or starting to settle.")
        case .anxiety:
            return ("Still in the thick of it?", "In the stressful moment, or winding down.")
        case .general, .none:
            return ("Feeling it right now?", "Mid-wave, or easing off.")
        }
    }

    private func contextQuestion(
        prompt: String,
        detail: String,
        selection: Bool?,
        idPrefix: String,
        onAnswer: @escaping (Bool) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.ink2)
            }
            HStack(spacing: 12) {
                answerButton("Yes", isOn: selection == true, id: "\(idPrefix)-yes") { onAnswer(true) }
                answerButton("No", isOn: selection == false, id: "\(idPrefix)-no") { onAnswer(false) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func answerButton(_ label: String, isOn: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? .white : Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isOn ? Theme.aqua : Theme.paper2, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// Once both context questions are answered, move to the recommendation.
    private func advanceIfComplete() {
        guard stillExposed != nil, recentlyAte != nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation { step = 3 }
        }
    }

    // MARK: - Step 4: recommendation

    private var recommendationStep: some View {
        Group {
            if let cause, let severity {
                RecommendationView(
                    checkIn: CheckIn(
                        cause: cause,
                        severity: severity,
                        stillExposed: stillExposed ?? false,
                        recentlyAte: recentlyAte ?? false
                    ),
                    onPlanReady: onPlanReady
                )
            } else {
                Color.clear
            }
        }
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.displaySerif(26))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
}

/// Shows the suggested mode, lets the user swap it, and hands off to the wrist
/// or the phone.
struct RecommendationView: View {
    let checkIn: CheckIn
    var onPlanReady: (ReliefPlan) -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss
    @State private var watchFeedback: String?
    @State private var chosenMode: ReliefMode?
    @State private var showPaywall = false
    /// Observed so the watch option appears the moment WCSession finishes
    /// activating, instead of the sheet freezing on whatever it read at open.
    @State private var watch = WatchAvailability.shared

    private var suggestedModes: [ReliefMode] {
        PatternEngine.suggestedModes(for: checkIn.cause)
    }

    private var mode: ReliefMode { chosenMode ?? suggestedModes[0] }

    private var plan: ReliefPlan {
        var resolved = checkIn
        resolved.mode = mode
        return AppSettings.shared.resolvedPlan(from: PatternEngine.recommend(for: resolved))
    }

    /// The length this session will actually run, after the free cap.
    private var effectiveSeconds: Int {
        FreeTier.cappedSeconds(
            for: mode,
            requested: plan.durationMinutes * 60,
            isPro: subscriptions.isProSubscriber
        )
    }

    private var isCapped: Bool {
        effectiveSeconds < plan.durationMinutes * 60
    }

    var body: some View {
        let plan = self.plan
        ScrollView {
            VStack(spacing: 18) {
                modePicker
                modeCard(plan: plan)
                startButtons(plan: plan)
                if isCapped { unlockLengthNote }
                if let note = checkIn.cause.safetyNote { safetyCard(note) }
                if !plan.tips.isEmpty { tipsCard(plan.tips) }
                disclaimer
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .task {
            AnalyticsService.checkInCompleted(cause: checkIn.cause, severity: checkIn.severity)
            settings.lastPlan = plan
        }
        .onAppear { watch.refresh() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(displayCloseButton: true, paywallImpressionId: "queasy_session_length")
        }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested for \(checkIn.cause.label.lowercased())")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestedModes) { candidate in
                        Button {
                            withAnimation(.snappy) { chosenMode = candidate }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: candidate.symbolName)
                                Text(candidate.title)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(candidate == mode ? .white : Theme.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .background(
                                candidate == mode ? Theme.aqua : Theme.paper2,
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("mode-\(candidate.rawValue)")
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Mode card

    @ViewBuilder
    private func modeCard(plan: ReliefPlan) -> some View {
        VStack(spacing: 12) {
            switch mode {
            case .pulse:
                intensityDial(plan.intensity)
                Text(specDescription(plan.spec))
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
            case .breathe:
                BreathingBloom(pattern: plan.breathe)
                    .frame(height: 130)
                Text("\(plan.breathe.label) · about \(plan.breathe.breathsPerMinute) breaths a minute")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
            case .tone:
                ZStack {
                    Circle().fill(Theme.aquaTint).frame(width: 130, height: 130)
                    Image(systemName: "waveform")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundStyle(Theme.aqua)
                }
                Text("100 Hz · one minute · headphones")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
            case .press:
                ZStack {
                    Circle().fill(Theme.aquaTint).frame(width: 130, height: 130)
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(Theme.aqua)
                }
                Text("Three minutes of steady pressure")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)
            }

            Text(mode.blurb)
                .font(.footnote)
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)

            Text(lengthLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.cardPadding)
        .tideCard()
    }

    private func intensityDial(_ intensity: Int) -> some View {
        ZStack {
            Circle().stroke(Theme.paper3, lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(intensity) / 10)
                .stroke(Theme.aqua, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(intensity)")
                    .font(Theme.roundedNumeric(44, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("of 10")
                    .font(.caption)
                    .foregroundStyle(Theme.ink3)
            }
        }
        .frame(width: 130, height: 130)
        .padding(.vertical, 4)
    }

    private var lengthLabel: String {
        let minutes = effectiveSeconds / 60
        switch mode {
        case .tone: return "One minute, then it stops on its own"
        case .press: return "Three minutes, timed for you"
        case .pulse, .breathe:
            return isCapped ? "\(minutes) minutes on the free plan" : "\(minutes) minutes"
        }
    }

    // MARK: - Start

    @ViewBuilder
    private func startButtons(plan: ReliefPlan) -> some View {
        VStack(spacing: 10) {
            if mode.runsOnWatch, watch.isPaired {
                Button {
                    start(plan: plan, onWatch: true)
                } label: {
                    Label(watchFeedback ?? "Start on Apple Watch",
                          systemImage: watchFeedback == nil ? "applewatch" : "checkmark")
                }
                .buttonStyle(.tideCTA)
                .accessibilityIdentifier("start-on-watch")

                Button {
                    start(plan: plan, onWatch: false)
                } label: {
                    Label("Use iPhone instead", systemImage: "iphone.radiowaves.left.and.right")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.aqua)
                }
                .accessibilityIdentifier("use-iphone")

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .font(.caption2)
                    Text("Not feeling anything on your wrist? Open Queasy on your Apple Watch once to finish installing and start the wrist session.")
                        .font(.caption2)
                }
                .foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
            } else {
                Button {
                    start(plan: plan, onWatch: false)
                } label: {
                    Label(phoneStartLabel, systemImage: mode.symbolName)
                }
                .buttonStyle(.tideCTA)
                .accessibilityIdentifier("use-iphone")

                if mode.needsHeadphones {
                    Text("Put headphones in first, and keep the volume low.")
                        .font(.caption2)
                        .foregroundStyle(Theme.ink3)
                }
            }
        }
    }

    private var phoneStartLabel: String {
        switch mode {
        case .pulse: return "Start the Pulse"
        case .breathe: return "Start Breathing"
        case .tone: return "Play the Tone"
        case .press: return "Start the Hold"
        }
    }

    private func start(plan: ReliefPlan, onWatch: Bool) {
        onPlanReady(plan)
        if onWatch {
            Task {
                let outcome = await WatchLauncher.shared.startOnWatch(plan: plan)
                watchFeedback = outcome == .started
                    ? "Starting on your watch…"
                    : "Sent. Open Queasy on your watch."
                try? await Task.sleep(for: .seconds(1.8))
                dismiss()
            }
        } else {
            // The home view watches the controller phase and presents the
            // session UI after this sheet dismisses.
            PhoneSessionController.shared.start(plan: plan, seconds: effectiveSeconds)
        }
    }

    // MARK: - Supporting cards

    private var unlockLengthNote: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.aqua)
                Text("Free sessions run \(FreeTier.sessionSeconds / 60) minutes. Pro runs the full \(plan.durationMinutes).")
                    .font(.caption)
                    .foregroundStyle(Theme.ink2)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .padding(14)
            .tideCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("unlock-length")
    }

    private func safetyCard(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "stethoscope")
                .font(.footnote)
                .foregroundStyle(Theme.ink2)
                .padding(.top, 2)
            Text(note)
                .font(.caption)
                .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tideCard(cornerRadius: 18)
    }

    private func tipsCard(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("While it runs")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.ink3)
                .textCase(.uppercase)
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.caption2)
                        .foregroundStyle(Theme.aqua)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .tideCard()
    }

    private var disclaimer: some View {
        Text("Queasy is a set of drug-free comfort techniques you run yourself. It is not a medical device, it does not diagnose or treat anything, and it may not change how you feel.")
            .font(.caption2)
            .foregroundStyle(Theme.ink3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    private func specDescription(_ spec: PulseSpec) -> String {
        let taps = spec.burstCount == 1 ? "Single tap" : "\(spec.burstCount)-tap burst"
        let strength: String
        switch spec.strength {
        case .soft: strength = "soft"
        case .medium: strength = "medium"
        case .strong: strength = "strong"
        }
        return "\(taps), \(strength), every \(String(format: "%.1f", spec.interval))s"
    }
}
