import Foundation

/// Count labels shown beside a number that is drawn separately ("3" beside
/// "queasy days"). A catalog plural variant has to contain its number, so these
/// labels cannot be plural keys themselves. Instead the catalog's
/// `"%lld plural category"` key returns the CLDR category for the user's
/// language ("few 3"), and each label has one whole key per category.
enum PluralLabel {
    enum Category: String {
        case one, few, many, other
    }

    static func category(_ count: Int) -> Category {
        let token = String(localized: "\(count) plural category")
        let word = token.split(separator: " ").first.map(String.init) ?? ""
        return Category(rawValue: word) ?? (count == 1 ? .one : .other)
    }

    /// "queasy day" / "queasy days", on the History heatmap.
    static func queasyDays(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "queasy day")
        case .few: String(localized: "queasy days (few)")
        case .many: String(localized: "queasy days (many)")
        case .other: String(localized: "queasy days")
        }
    }

    /// "calm day" / "calm days", on the History heatmap.
    static func calmDays(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "calm day")
        case .few: String(localized: "calm days (few)")
        case .many: String(localized: "calm days (many)")
        case .other: String(localized: "calm days")
        }
    }

    /// "sessions\nthis week", under the History stat tile's count. English has
    /// one wording, so its `(one)` key reads the same.
    static func sessionsThisWeek(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "sessions\nthis week (one)")
        case .few: String(localized: "sessions\nthis week (few)")
        case .many: String(localized: "sessions\nthis week (many)")
        case .other: String(localized: "sessions\nthis week")
        }
    }
}
