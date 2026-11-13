import SwiftUI
import UIKit

enum DeviceIdiom {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
}

extension View {
    /// Keeps a screen's content to a readable measure and centres it. A no-op
    /// on a phone, where the screen is already narrower than `width`.
    func readableColumn(_ width: CGFloat = 600) -> some View {
        frame(maxWidth: width)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// An iPad's default form sheet is too short for the mode and check-in
    /// screens, so the Start button falls below the fold. A page-sized sheet
    /// fits them. Earlier systems keep the form sheet.
    @ViewBuilder
    func padPageSheet() -> some View {
        if #available(iOS 18.0, *), DeviceIdiom.isPad {
            presentationSizing(.page)
        } else {
            self
        }
    }
}

extension ReliefMode {
    /// The modes this device can run. An iPad has no haptic engine, so Pulse,
    /// a steady tap, has nothing to play there.
    static var available: [ReliefMode] {
        DeviceIdiom.isPad ? allCases.filter { $0 != .pulse } : allCases
    }

    /// `self`, or the first mode this device can run.
    var onThisDevice: ReliefMode {
        Self.available.contains(self) ? self : (Self.available.first ?? self)
    }
}

extension ReliefMode {
    /// On an iPad Breathe has no wrist to tap: the circle sets the pace.
    var cardTagline: String {
        guard DeviceIdiom.isPad, self == .breathe else { return tagline }
        return String(localized: "Slow the breath, paced on screen")
    }

    var detailBlurb: String {
        guard DeviceIdiom.isPad, self == .breathe else { return blurb }
        return String(localized: "A circle grows and fades at a steady pace so you can slow your breath to match. Breathing out for longer than you breathe in is the whole technique.")
    }
}

/// A scroll view that floats content shorter than the screen a little above
/// centre, so a short screen on a tall iPad does not hug the top.
/// Taller content scrolls as usual. A phone never centres.
struct CenteringScrollView<Content: View>: View {
    @State private var height: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            // Leftover height splits one part above, two below: the content
            // sits a little above centre, the way it reads on a tall screen.
            VStack(spacing: 0) {
                Color.clear.frame(maxHeight: .infinity)
                content
                Color.clear.frame(maxHeight: .infinity)
                Color.clear.frame(maxHeight: .infinity)
            }
            .frame(minHeight: DeviceIdiom.isPad ? max(height - 140, 0) : 0)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
    }
}
