import Foundation

/// The four things Queasy can do. Splitting these out is the whole point of the
/// 2026-08 rebuild: 1.0 shipped one modality (a wrist buzz) carrying an implied
/// mechanism it could not support, which is what App Review hit under 1.1.6.
/// Each mode here is something the user does, described by what it literally
/// is. See `docs/positioning.md` for the copy rules.
enum ReliefMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Rhythmic taps on the inside of the wrist. Something steady to focus on.
    case pulse
    /// A paced breath you feel rather than watch.
    case breathe
    /// The 100 Hz tone from the 2025 Nagoya study, through headphones.
    case tone
    /// Coaching for the P6 spot an acupressure band sits on: find it, hold it,
    /// time it. The technique the trials actually ran.
    case press

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pulse: return "Pulse"
        case .breathe: return "Breathe"
        case .tone: return "Tone"
        case .press: return "Press"
        }
    }

    /// One line, on the card. States what happens, never what it will do to you.
    var tagline: String {
        switch self {
        case .pulse: return "A steady tap on the inside of your wrist"
        case .breathe: return "Slow the breath, paced by your wrist"
        case .tone: return "A 100 Hz tone through your headphones"
        case .press: return "Find the spot a band sits on, and hold it"
        }
    }

    /// Two or three lines, on the mode's own screen.
    var blurb: String {
        switch self {
        case .pulse:
            return "An unhurried, regular tap you can rest your attention on while a wave passes. Nudge the level until it is clear but not annoying."
        case .breathe:
            return "Your watch taps the rhythm so you can keep your eyes shut: a long tap in, a longer one out. Breathing out for longer than you breathe in is the whole technique."
        case .tone:
            return "A pure 100 Hz tone at a low volume. Headphones, one minute, eyes wherever you like."
        case .press:
            return "The inside of the wrist, three finger-widths below the crease, between the two tendons. Press with your thumb, or line up the stud on a band you already own."
        }
    }

    var symbolName: String {
        switch self {
        case .pulse: return "dot.radiowaves.left.and.right"
        case .breathe: return "wind"
        case .tone: return "waveform"
        case .press: return "hand.point.up.left.fill"
        }
    }

    /// Modes that can run on the wrist with the screen off.
    var runsOnWatch: Bool {
        switch self {
        case .pulse, .breathe, .press: return true
        case .tone: return false
        }
    }

    var needsHeadphones: Bool { self == .tone }

    /// Modes whose length the user (or the check-in) chooses. Tone and Press run
    /// a fixed protocol instead, so they are the same length free or paid.
    var hasVariableDuration: Bool {
        switch self {
        case .pulse, .breathe: return true
        case .tone, .press: return false
        }
    }

    /// What the mode leans on, shown under it in Learn with the source. Kept in
    /// the source's own hedged words on purpose.
    var evidenceNote: String? {
        switch self {
        case .pulse:
            return nil
        case .breathe:
            return "Trials of slow diaphragmatic breathing during chemotherapy and after surgery have reported lower nausea scores. The studies are small."
        case .tone:
            return "A 2025 Nagoya University study is titled \"Just 1-min exposure to a pure tone at 100 Hz with daily exposable sound pressure levels may improve motion sickness\"."
        case .press:
            return "Pressure at this spot has been trialled for travel, post-surgery and pregnancy sickness. The Cochrane review of early-pregnancy trials calls the evidence limited and inconsistent."
        }
    }

    var sourceURL: URL? {
        switch self {
        case .pulse:
            return nil
        case .breathe:
            return URL(string: "https://pubmed.ncbi.nlm.nih.gov/41811802/")
        case .tone:
            return URL(string: "https://doi.org/10.1265/ehpm.24-00247")
        case .press:
            return URL(string: "https://www.cochranelibrary.com/cdsr/doi/10.1002/14651858.CD007575.pub4/full")
        }
    }
}

/// A paced-breathing rhythm. Exhale longer than inhale; that is the technique.
struct BreathePattern: Codable, Sendable, Equatable {
    var inhaleSeconds: Double
    var exhaleSeconds: Double

    static let relaxed = BreathePattern(inhaleSeconds: 4, exhaleSeconds: 6)
    static let slower = BreathePattern(inhaleSeconds: 4, exhaleSeconds: 8)
    static let gentle = BreathePattern(inhaleSeconds: 3, exhaleSeconds: 5)

    static let all: [BreathePattern] = [.gentle, .relaxed, .slower]

    var cycleSeconds: Double { inhaleSeconds + exhaleSeconds }

    var label: String {
        "\(Int(inhaleSeconds)) in · \(Int(exhaleSeconds)) out"
    }

    var breathsPerMinute: Int { Int((60.0 / cycleSeconds).rounded()) }
}

/// How Press is dosed. The numbers come from the wristband trials: a few
/// minutes of steady pressure, repeated through the day, rather than one go.
enum PressProtocol {
    static let holdSeconds = 180
    static let suggestedDailyHolds = 3

    /// Finding the spot. Deliberately physical instructions with no claim about
    /// what happens once you are there.
    static let steps: [String] = [
        "Turn one hand palm up.",
        "Lay three fingers of the other hand across the wrist, just below the crease.",
        "The spot is under the edge of your third finger, in the dip between the two tendons.",
        "Press firmly with your thumb, or sit the stud of an acupressure band there.",
        "Do the same on the other wrist if you have a second band.",
    ]
}
