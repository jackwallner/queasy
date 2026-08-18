import Foundation

enum AppStoreReviewLinks {
    static let appStoreID = "6786780495"

    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }
}
