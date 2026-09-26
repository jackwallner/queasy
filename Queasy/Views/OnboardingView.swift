import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @State private var page = 0
    @State private var watch = WatchAvailability.shared

    private let lastPage = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                OnboardPage(
                    symbol: "square.grid.2x2",
                    title: "Four things to try\nwhen you feel sick",
                    text: "A steady tap on your wrist. A paced breath you feel rather than watch. A one-minute 100 Hz tone. A timed hold on the spot an acupressure band sits on. All drug-free, all free to use."
                )
                .tag(0)

                OnboardPage(
                    symbol: "list.bullet.clipboard",
                    title: "Or answer three\nquick questions",
                    text: "Tell Queasy what kind of queasy moment you are in and how strong it feels. It picks a mode, a level and a length, and shows you what each one leans on so you can judge it yourself."
                )
                .tag(1)

                OnboardPage(
                    symbol: "applewatch.side.right",
                    title: "Turn the watch to\nthe inside of your wrist",
                    text: "For Pulse and Press, rotate your watch so the case sits on the inside of your wrist, three finger-widths below the crease. That is where a Sea-Band's stud goes. Breathe works wherever the watch is."
                )
                .tag(2)

                watchGatePage
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 10) {
                if page < lastPage {
                    Button("Continue") {
                        withAnimation { page += 1 }
                    }
                    .buttonStyle(.tideCTA)
                    .accessibilityIdentifier("onboarding-continue")
                } else {
                    gateButtons
                }

                Text("Queasy is a set of comfort techniques, not a medical device.\nIt does not diagnose, treat or cure anything, and it may not\nchange how you feel. If symptoms are severe or persistent,\ntalk to a doctor.")
                    .font(.caption2)
                    .foregroundStyle(Theme.ink3)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
        }
        .tideBackground()
        .onAppear { watch.refresh() }
    }

    // MARK: - Watch gate (last page)

    /// The wrist is the product. Ready/installing watches sail through; users
    /// without one must explicitly choose the iPhone fallback.
    private var watchGatePage: some View {
        OnboardPage(
            symbol: watch.isAppInstalled ? "checkmark.applewatch" : "applewatch",
            title: gateTitle,
            text: gateText
        )
    }

    private var gateTitle: String {
        if watch.isAppInstalled { return "Your watch\nis ready" }
        if watch.isPairedWithoutApp { return "Setting up\nyour watch" }
        return "Built for\nApple Watch"
    }

    private var gateText: String {
        if watch.isAppInstalled {
            return "Queasy is on your Apple Watch. Sessions play on your wrist and keep running with the screen off."
        }
        if watch.isPairedWithoutApp {
            return "Queasy is installing on your Apple Watch now. It appears there automatically, and wrist sessions start working the moment it finishes. You can run your first session from your iPhone in the meantime."
        }
        return "Pulse, Breathe and Press are meant to be felt on your wrist, which is what the Apple Watch app is for. Without one, your iPhone's own vibration stands in: rest it against you, or hold it to the inside of your wrist. Tone works on either."
    }

    @ViewBuilder
    private var gateButtons: some View {
        if watch.isPaired {
            Button("Get Started") {
                settings.hasCompletedOnboarding = true
            }
            .buttonStyle(.tideCTA)
            .accessibilityIdentifier("onboarding-continue")
        } else {
            Button("I'll Use My Apple Watch") {
                settings.hasCompletedOnboarding = true
            }
            .buttonStyle(.tideCTA)
            .accessibilityIdentifier("onboarding-continue")

            Button("Continue with iPhone only. I understand Queasy is designed for Apple Watch.") {
                settings.phoneOnlyAcknowledged = true
                settings.hasCompletedOnboarding = true
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.ink2)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("onboarding-phone-only")
        }
    }
}

private struct OnboardPage: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle().fill(Theme.aquaTint).frame(width: 150, height: 150)
                Image(systemName: symbol)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(Theme.aqua)
            }
            Text(title)
                .font(Theme.displaySerif(30))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(text)
                .font(.callout)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
            Spacer()
        }
    }
}
