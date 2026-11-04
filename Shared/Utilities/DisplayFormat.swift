import Foundation

/// Locale-aware rendering of numbers and clocks. In US English the output matches
/// the app's wording ("4:05", "1.5", "+1.3"); other locales get their own forms
/// from Foundation.
enum DisplayFormat {
    /// "4:05"
    static func clock(_ seconds: Int) -> String {
        Duration.seconds(max(seconds, 0)).formatted(.time(pattern: .minuteSecond))
    }

    /// "1.5"
    static func oneDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    /// "+1.3", "-0.5"
    static func signedOneDecimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always(includingZero: true)))
    }
}
