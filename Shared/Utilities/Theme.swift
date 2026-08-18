import SwiftUI

/// Tide design system. Calm seafoam canvas, deep petrol ink, aqua brand accent.
/// watchOS uses literal dark values legible on the black watch background.
enum Theme {
    #if os(watchOS)
    static let paper  = Color(red: 0.075, green: 0.106, blue: 0.110)
    static let paper2 = Color(red: 0.110, green: 0.153, blue: 0.157)
    static let paper3 = Color(red: 0.145, green: 0.200, blue: 0.204)
    static let ink    = Color(red: 0.925, green: 0.953, blue: 0.949)
    static let ink2   = Color(red: 0.663, green: 0.749, blue: 0.741)
    static let ink3   = Color(red: 0.447, green: 0.541, blue: 0.533)
    static let aqua     = Color(red: 0.416, green: 0.780, blue: 0.729)
    static let aquaTint = Color(red: 0.110, green: 0.216, blue: 0.204)
    static let sand     = Color(red: 0.910, green: 0.784, blue: 0.588)
    static let sandTint = Color(red: 0.227, green: 0.196, blue: 0.145)
    static let coral     = Color(red: 0.925, green: 0.608, blue: 0.553)
    static let coralTint = Color(red: 0.231, green: 0.153, blue: 0.137)
    #else
    static let paper  = Color(red: 0.918, green: 0.953, blue: 0.949) // #EAF3F2 seafoam canvas
    static let paper2 = Color.white                                   // card
    static let paper3 = Color(red: 0.949, green: 0.973, blue: 0.969) // #F2F8F7 track/divider
    static let ink    = Color(red: 0.141, green: 0.224, blue: 0.243) // #24393E deep petrol
    static let ink2   = Color(red: 0.361, green: 0.451, blue: 0.471) // #5C7378 secondary
    static let ink3   = Color(red: 0.549, green: 0.635, blue: 0.651) // #8CA2A6 tertiary
    static let aqua     = Color(red: 0.333, green: 0.710, blue: 0.663) // #55B5A9 brand
    static let aquaTint = Color(red: 0.855, green: 0.941, blue: 0.925) // pale aqua wash
    static let sand     = Color(red: 0.910, green: 0.784, blue: 0.588) // #E8C896 moderate
    static let sandTint = Color(red: 0.980, green: 0.945, blue: 0.882)
    static let coral     = Color(red: 0.910, green: 0.576, blue: 0.541) // #E8938A severe
    static let coralTint = Color(red: 0.980, green: 0.910, blue: 0.898)
    #endif

    // MARK: - Severity

    /// 1-5 check-in severity → color ramp (calm → urgent).
    static func severityColor(_ severity: Int) -> Color {
        switch severity {
        case ...2: return aqua
        case 3: return sand
        default: return coral
        }
    }

    static let background  = paper
    static let cardSurface = paper2

    // MARK: - Geometry

    static let cardRadius: CGFloat = 24
    static let cardPadding: CGFloat = 22
    static let ctaRadius: CGFloat = 28

    // MARK: - Type

    /// Ritual serif italic — house style for the moments you pause for.
    static func displaySerif(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic()
    }

    static func roundedNumeric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    /// Page wash: aqua cresting at the top, fading into the seafoam canvas.
    static var tideWash: LinearGradient {
        LinearGradient(
            colors: [aquaTint, paper, paper],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// CTA fill: aqua with a slightly deeper foot so buttons read dimensional.
    static var ctaGradient: LinearGradient {
        LinearGradient(
            colors: [aqua, aquaDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    #if os(watchOS)
    static let aquaDeep = Color(red: 0.322, green: 0.647, blue: 0.600)
    #else
    static let aquaDeep = Color(red: 0.243, green: 0.604, blue: 0.557) // #3E9A8E
    #endif
}

extension View {
    func tideBackground() -> some View {
        background(Theme.tideWash.ignoresSafeArea())
    }

    /// Translucent card with a hairline edge and a soft drop on the tide wash.
    func tideCard(cornerRadius: CGFloat = Theme.cardRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(shape.fill(Theme.paper2.opacity(0.6)))
            .background(shape.fill(.ultraThinMaterial))
            .overlay(shape.stroke(Theme.ink.opacity(0.06), lineWidth: 1))
            .compositingGroup()
            .shadow(color: Theme.ink.opacity(0.07), radius: 14, y: 6)
    }
}

#if os(iOS)
extension View {
    /// Brand navigation title: inline ritual serif, same treatment on every tab.
    func tideNavigationTitle(_ title: String) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Theme.displaySerif(20))
                        .foregroundStyle(Theme.ink)
                }
            }
    }
}
#endif

/// Primary CTA button style shared across screens.
struct TideCTAStyle: ButtonStyle {
    var tint: Color = Theme.aqua
    var height: CGFloat = 52
    var font: Font = .system(.headline, design: .rounded)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Theme.ctaGradient, in: RoundedRectangle(cornerRadius: Theme.ctaRadius))
            .shadow(color: tint.opacity(configuration.isPressed ? 0.1 : 0.35), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TideCTAStyle {
    static var tideCTA: TideCTAStyle { TideCTAStyle() }
    /// Oversized home-screen variant: the user is queasy, make the target huge.
    static var tideCTAHero: TideCTAStyle {
        TideCTAStyle(height: 64, font: .system(.title3, design: .rounded, weight: .semibold))
    }
}
