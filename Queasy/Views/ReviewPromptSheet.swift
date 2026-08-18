import SwiftUI
import UIKit

/// Presents the two-step review funnel from anywhere. A session-rating screen
/// sets `pendingStep` then dismisses itself; `RootTabView` watches this and
/// shows the sheet once the session cover is out of the way.
@MainActor
@Observable
final class ReviewPromptCoordinator {
    static let shared = ReviewPromptCoordinator()
    private init() {}

    var pendingStep: ReviewPromptSheet.Step?

    func request(_ step: ReviewPromptSheet.Step = .enjoyment) {
        pendingStep = step
    }

    func clear() { pendingStep = nil }
}

/// Pre-ask sentiment, then route: users who say they're feeling better go to the
/// App Store write-review page; users who aren't go to a private feedback email,
/// so a rough experience becomes a message to the developer, not a public 1-star.
/// Only ever shown after a session that actually settled someone (gated upstream
/// by `ReviewPromptTracker`), so we're only asking people who like the app.
struct ReviewPromptSheet: View {
    enum Step: Equatable {
        case enjoyment
        case reviewPitch
        case feedback
    }

    let initialStep: Step

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var feedbackText = ""
    @FocusState private var feedbackFocused: Bool

    init(initialStep: Step = .enjoyment) {
        self.initialStep = initialStep
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                switch step {
                case .enjoyment: enjoymentContent
                case .reviewPitch: reviewPitchContent
                case .feedback: feedbackContent
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .foregroundStyle(Theme.ink2)
                }
            }
        }
        .presentationDetents(step == .feedback ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var navigationTitle: String {
        switch step {
        case .enjoyment: "Feeling better?"
        case .reviewPitch: "Support an indie dev"
        case .feedback: "Help us improve"
        }
    }

    // MARK: - Step 1: sentiment

    private var enjoymentContent: some View {
        VStack(spacing: 22) {
            iconBadge("heart.fill")
                .padding(.top, 8)

            Text("Is Queasy helping you feel more comfortable?")
                .font(Theme.displaySerif(24))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                Button("Yes, it's helping") { step = .reviewPitch }
                    .buttonStyle(.tideCTA)
                Button("Not really") { step = .feedback }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink2)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    // MARK: - Step 2a: review pitch (happy path)

    private var reviewPitchContent: some View {
        VStack(spacing: 18) {
            iconBadge("star.fill")
                .padding(.top, 8)

            Text("Queasy is built by one indie developer, with no ads and no accounts. An honest App Store review takes seconds and lets more people discover drug-free comfort tools.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                Button("Rate on the App Store") {
                    ReviewPromptTracker.markResolved()
                    UIApplication.shared.open(AppStoreReviewLinks.writeReviewURL)
                    dismiss()
                }
                .buttonStyle(.tideCTA)

                Button("Maybe later") { dismiss() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink2)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    // MARK: - Step 2b: feedback (unhappy path)

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would make Queasy work better for you?")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $feedbackText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
                .padding(10)
                .background(Theme.paper2, in: RoundedRectangle(cornerRadius: 14))
                .focused($feedbackFocused)

            Text("Opens Mail with a draft to the developer. No accounts, no analytics, just your words.")
                .font(.caption)
                .foregroundStyle(Theme.ink3)

            Button("Send feedback") { sendFeedback() }
                .buttonStyle(.tideCTA)
                .disabled(trimmedFeedback.isEmpty)
                .opacity(trimmedFeedback.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { feedbackFocused = true }
    }

    private var trimmedFeedback: String {
        feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendFeedback() {
        guard !trimmedFeedback.isEmpty, let url = Self.feedbackMailURL(body: trimmedFeedback) else { return }
        ReviewPromptTracker.markResolved()
        UIApplication.shared.open(url)
        dismiss()
    }

    private func iconBadge(_ symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(Theme.ctaGradient)
                .frame(width: 64, height: 64)
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    /// Pre-filled mailto for private, account-free feedback.
    static func feedbackMailURL(body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "jackwallner+q@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Queasy feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
