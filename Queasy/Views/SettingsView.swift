import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SubscriptionService.self) private var subscriptions
    @State private var isRestoring = false
    @State private var showPaywall = false
    @State private var restoreMessage: String?
    @State private var reminders = PressReminderService.shared

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            List {
                Section {
                    Picker("Session length", selection: $settings.defaultDurationMinutes) {
                        Text("Match my symptoms").tag(Int?.none)
                        ForEach([10, 15, 20, 30], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(Int?.some(minutes))
                        }
                    }
                    Picker("Breathing rhythm", selection: $settings.defaultBreatheIndex) {
                        Text("Match my symptoms").tag(Int?.none)
                        ForEach(Array(BreathePattern.all.enumerated()), id: \.offset) { index, pattern in
                            Text(pattern.label).tag(Int?.some(index))
                        }
                    }
                    Picker("Watch pulse cap", selection: $settings.watchStrengthCap) {
                        Text("Soft").tag(PulseStrength.soft)
                        Text("Medium").tag(PulseStrength.medium)
                        Text("Strong").tag(PulseStrength.strong)
                    }
                } header: {
                    Text("Session")
                } footer: {
                    if !subscriptions.isProSubscriber {
                        Text("Pulse and Breathe run \(FreeTier.sessionSeconds / 60) minutes on the free plan, however long you set here. Tone and Press always run their full length.")
                    }
                }

                Section {
                    Toggle("Press reminders", isOn: Binding(
                        get: { reminders.isEnabled },
                        set: { wanted in
                            guard subscriptions.isProSubscriber else {
                                showPaywall = true
                                return
                            }
                            Task { await reminders.setEnabled(wanted) }
                        }
                    ))
                    .tint(Theme.aqua)
                    .accessibilityIdentifier("press-reminders")
                } header: {
                    Text("Press")
                } footer: {
                    if reminders.authorizationDenied {
                        Text("Notifications are off for Queasy. Turn them on in iOS Settings to use reminders.")
                    } else if subscriptions.isProSubscriber {
                        Text("A nudge at \(reminders.scheduleLabel) to run a three-minute hold, the way the wristband trials spaced them.")
                    } else {
                        Text("Queasy Pro nudges you a few times a day to run a hold, the way the wristband trials spaced them.")
                    }
                }

                Section {
                    Toggle("Calendar heatmap", isOn: $settings.showHistoryHeatmap)
                        .tint(Theme.aqua)
                } header: {
                    Text("History")
                } footer: {
                    Text("Shows a day-by-day grid on the History tab.")
                }

                Section("Queasy Pro") {
                    if subscriptions.isProSubscriber {
                        Label("Active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(Theme.aqua)
                    } else {
                        // With no gate on the way in, this is the durable place
                        // to buy. The full plan picker, per the paywall playbook.
                        Button {
                            showPaywall = true
                        } label: {
                            Label("See Queasy Pro", systemImage: "sparkles")
                                .foregroundStyle(Theme.aqua)
                        }
                        .accessibilityIdentifier("settings-see-pro")
                    }
                    Button(isRestoring ? "Restoring…" : "Restore Purchases") {
                        restore()
                    }
                    .disabled(isRestoring)
                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.ink3)
                    }
                }

                Section("About") {
                    Link("Rate Queasy", destination: AppStoreReviewLinks.writeReviewURL)
                    Link("Contact Support", destination: PaywallLinks.support)
                    Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
                    Link("Terms of Use", destination: PaywallLinks.standardEULA)
                    LabeledContent("Version", value: versionString)
                }

                Section {
                    Text("Queasy is a set of comfort techniques you run yourself, not a medical device, and it holds no clearance. It does not diagnose, treat, cure or prevent anything, and it may not change how you feel. If nausea is severe or persistent, talk to a doctor.")
                        .font(.caption)
                        .foregroundStyle(Theme.ink3)
                }

                #if DEBUG
                Section("Debug") {
                    Toggle("Pro override", isOn: Binding(
                        get: { subscriptions.isProSubscriber },
                        set: { subscriptions.setLocalOverride(isPro: $0) }
                    ))
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .tideBackground()
            .tideNavigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView(displayCloseButton: true, paywallImpressionId: "queasy_settings")
            }
            .task {
                // Reminders are a Pro feature, so a lapsed subscription stops
                // them; the stored preference stays so resubscribing restores it.
                if subscriptions.isProSubscriber {
                    await reminders.refresh()
                } else {
                    reminders.suspendForNonSubscriber()
                }
            }
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func restore() {
        isRestoring = true
        restoreMessage = nil
        Task {
            defer { isRestoring = false }
            #if HAS_REVENUECAT
            await subscriptions.restorePurchases()
            restoreMessage = subscriptions.isProSubscriber ? "Restored." : "No purchases found."
            #else
            await subscriptions.refresh()
            #endif
        }
    }
}
