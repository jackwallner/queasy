import SwiftUI

/// The Learn tab: a plain scrollable list of topics. Each row shows its
/// one-line hook; tap to expand the full explanation inline (a disclosure/
/// accordion, the pattern Apple Health and most wellness apps use for short
/// reference content). No decks, no card flips, just a list you read down.
struct LearnView: View {
    /// The topic currently expanded, if any. One open at a time keeps the page
    /// from becoming a wall of text.
    @State private var expandedID: String? = Self.debugExpandedID

    /// `-QueasyLearnCard <id>` opens a topic on launch, for capture on a
    /// headless simulator that cannot be tapped. DEBUG only.
    private static var debugExpandedID: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-QueasyLearnCard"), args.indices.contains(flag + 1) else { return nil }
        return args[flag + 1]
        #else
        return nil
        #endif
    }

    private static func source(_ title: String, _ url: String) -> LearnSource {
        LearnSource(title: title, url: URL(string: url)!)
    }

    private static let cards: [LearnCard] = [
        LearnCard(
            id: "pulse",
            symbol: "dot.radiowaves.left.and.right",
            title: "Pulse, and what it is not",
            hook: "A steady tap to rest your attention on.",
            detail: "Pulse taps your wrist on a regular, unhurried beat. That is the whole of it. Nudge the level until the tap is clear but not annoying, and let it be the thing you notice instead of the surroundings. Pulse is a self-guided comfort routine, not medical care."
        ),
        LearnCard(
            id: "breathe",
            symbol: "wind",
            title: "Breathe",
            hook: "Out for longer than in, paced by your wrist.",
            detail: "Your watch taps a long swell in, then a longer fade out, so you can keep your eyes shut and follow it. Queasy suggests three seconds in and five out when things are mild, and four in and eight out when they are not. Breathing out for longer than you breathe in is the whole technique.\n\nThis is a complementary wellness routine you run yourself, not medical care. Stop if it feels uncomfortable, and talk with a clinician if nausea is severe or persistent."
        ),
        LearnCard(
            id: "tone",
            symbol: "waveform",
            title: "The 100 Hz tone",
            hook: "One minute, headphones, low volume.",
            detail: "A pure 100 Hz tone at a low volume. Headphones, one minute, eyes wherever you like. Keep the volume comfortable and stop whenever you want. Queasy provides a self-guided listening routine, not medical care.",
        ),
        LearnCard(
            id: "press",
            symbol: "hand.point.up.left.fill",
            title: "Press",
            hook: "A comfortable hold on the inside of your wrist.",
            detail: "Choose a comfortable place on the inside of your wrist and rest your thumb there without pressing hard. Press shows simple steps and times a three-minute hold. Adjust the pressure to a comfortable level, stop whenever you want, and treat this as a self-guided comfort routine rather than medical care.",
        ),
        LearnCard(
            id: "wear",
            symbol: "applewatch.side.right",
            title: "How to wear your watch",
            hook: "Case on the inside of your wrist, snug.",
            detail: "For Pulse and Press, loosen the band and rotate your watch so the case sits on the inside of your wrist. Snug enough that you feel each tap or timer cue clearly. Rotate it back when you are done; sessions are short.\n\nBreathe does not care where the watch is. You only need to feel it."
        ),
        LearnCard(
            id: "morning",
            symbol: "sunrise.fill",
            title: "Before you travel",
            hook: "Small, practical ways to make a journey easier.",
            detail: "Keep water close, choose a comfortable seat, and give yourself a little extra time before the journey starts. A cool cabin, a steady gaze, and a simple routine can make the next few minutes feel more manageable.\n\nQueasy offers self-guided comfort routines only. Pause if anything feels uncomfortable and ask a clinician about symptoms that are severe or persistent.",
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Self.cards) { card in
                        LearnRow(
                            card: card,
                            isExpanded: expandedID == card.id
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                expandedID = expandedID == card.id ? nil : card.id
                            }
                        }
                    }
                    disclaimerCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .tideBackground()
            .tideNavigationTitle("Learn")
        }
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Not a medical device", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink2)
            Text("Queasy is a set of drug-free comfort techniques you run yourself. It is not a medical device and holds no clearance. It does not diagnose, treat, cure or prevent anything, and it may not change how you feel. Bands like Sea-Band and devices like Reliefband are cleared medical devices; Queasy is not one of them and is not a substitute for one. If nausea is severe, persistent, comes with other symptoms, or you cannot keep fluids down, see a doctor.")
                .font(.caption)
                .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.paper3, in: RoundedRectangle(cornerRadius: 16))
        .padding(.top, 4)
    }
}

struct LearnCard: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let hook: String
    let detail: String
    var sources: [LearnSource] = []
}

struct LearnSource: Identifiable {
    let title: String
    let url: URL

    var id: String { url.absoluteString }
}

/// One topic. Header (icon + title + hook + chevron) is always visible; the
/// detail slides in below when expanded.
private struct LearnRow: View {
    let card: LearnCard
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: card.symbol)
                        .font(.body)
                        .foregroundStyle(Theme.aqua)
                        .frame(width: 38, height: 38)
                        .background(Theme.aquaTint, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        Text(card.hook)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.ink3)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.top, 10)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(card.detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !card.sources.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Sources")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.ink3)
                            ForEach(card.sources) { source in
                                Link(destination: source.url) {
                                    Label(source.title, systemImage: "link")
                                        .font(.caption)
                                        .foregroundStyle(Theme.aquaDeep)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.leading, 50)
                // Fade in place. A `.move` transition slides multiline text
                // under the header while the row height springs open.
                .transition(.opacity)
            }
        }
        .padding(Theme.cardPadding)
        .tideCard()
    }
}
