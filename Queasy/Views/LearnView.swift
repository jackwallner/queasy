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
            detail: "Pulse taps your wrist on a regular, unhurried beat. That is the whole of it. Nudge the level until the tap is clear but not annoying, and let it be the thing you notice instead of your stomach, the way you might count breaths or stare at the horizon.\n\nWorth being straight about: a watch tapping your wrist is not acupressure and not nerve stimulation. Those are different things, done by bands that press or by cleared devices that deliver current, and no trial has tested a watch buzz in their place. Pulse is here because a predictable sensation is easy to focus on, not because it does something to you."
        ),
        LearnCard(
            id: "breathe",
            symbol: "wind",
            title: "Breathe",
            hook: "Out for longer than in, paced by your wrist.",
            detail: "Your watch taps a long swell in, then a longer fade out, so you can keep your eyes shut and follow it. Queasy suggests three seconds in and five out when things are mild, and four in and eight out when they are not. Breathing out for longer than you breathe in is the whole technique.\n\nSmall trials of slow diaphragmatic breathing during chemotherapy and after surgery have reported lower nausea scores. They are small, and the reviewers say so.",
            sources: [
                source("Breathing interventions for nausea (2026 trial)", "https://pubmed.ncbi.nlm.nih.gov/41811802/"),
                source("Diaphragmatic breathing during chemotherapy", "https://www.sciencedirect.com/science/article/abs/pii/S1462388924000462"),
            ]
        ),
        LearnCard(
            id: "tone",
            symbol: "waveform",
            title: "The 100 Hz tone",
            hook: "One minute, headphones, low volume.",
            detail: "In 2025 a Nagoya University group published a paper whose title says it plainly: \"Just 1-min exposure to a pure tone at 100 Hz with daily exposable sound pressure levels may improve motion sickness\". They measured posture, heart rhythm and questionnaire scores after a minute of a 100 Hz tone at everyday volume.\n\nQueasy generates that tone. May improve is the authors' own wording, and it is worth keeping. Headphones, volume low enough that it sits under the noise around you.",
            sources: [
                source("Nagoya University: a unique sound alleviates motion sickness", "https://en.nagoya-u.ac.jp/news/articles/research_information_267/"),
                source("Environmental Health and Preventive Medicine (DOI)", "https://doi.org/10.1265/ehpm.24-00247"),
            ]
        ),
        LearnCard(
            id: "press",
            symbol: "hand.point.up.left.fill",
            title: "Press, and the P6 spot",
            hook: "The spot an acupressure band sits on.",
            detail: "Nei-Kuan, or P6, sits on the inside of the forearm about three finger-widths below the wrist crease, in the dip between the two tendons. It is where the stud of a Sea-Band lands, and where the trials put their pressure.\n\nPress does not press for you. It shows you the spot, then times a three-minute hold while you use your thumb or line up a band you already own. The wristband trials spaced their holds through the day rather than doing one long one.\n\nThe evidence is genuinely mixed. Some trials in pregnancy and after surgery report lower nausea scores; the Cochrane review of early-pregnancy trials calls the P6 evidence limited and inconsistent. Both of those things are true at once.",
            sources: [
                source("Cochrane: nausea and vomiting in early pregnancy", "https://www.cochranelibrary.com/cdsr/doi/10.1002/14651858.CD007575.pub4/full"),
                source("Cochrane: PC6 wrist stimulation evidence", "https://www.cochrane.org/evidence/CD003281_what-are-benefits-and-risks-different-wrist-pc6-acupoint-stimulation-techniques-preventing-nausea"),
                source("Memorial Sloan Kettering: locating P6", "https://www.mskcc.org/cancer-care/patient-education/acupressure-nausea-and-vomiting"),
            ]
        ),
        LearnCard(
            id: "wear",
            symbol: "applewatch.side.right",
            title: "How to wear your watch",
            hook: "Case on the inside of your wrist, snug.",
            detail: "For Pulse and Press, loosen the band and rotate your watch so the case sits on the inside of your wrist. Snug enough that you feel each tap clearly. Rotate it back when you are done; sessions are short.\n\nBreathe does not care where the watch is. You only need to feel it."
        ),
        LearnCard(
            id: "morning",
            symbol: "sunrise.fill",
            title: "Morning sickness",
            hook: "What tends to help, and when to call someone.",
            detail: "It is rarely only mornings, and an empty stomach is the usual trigger, so small and often beats three meals. Plain crackers before you sit up, cold food rather than hot because it carries less smell, fluids between meals rather than with them. Acupressure bands are one of the drug-free things people try; so is vitamin B6, which your midwife or doctor can advise on.\n\nCall your midwife or doctor if you cannot keep fluids down for a day, if you are losing weight, if you feel faint, or if you are passing very dark urine. Severe pregnancy sickness has a name, hyperemesis gravidarum, and it has treatment. An app is not it.",
            sources: [
                source("NHS: vomiting and morning sickness", "https://www.nhs.uk/pregnancy/related-conditions/common-symptoms/vomiting-and-morning-sickness/"),
                source("ACOG: morning sickness", "https://www.acog.org/womens-health/faqs/morning-sickness-nausea-and-vomiting-of-pregnancy"),
            ]
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
