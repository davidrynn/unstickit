import Foundation
import Combine

/// Logs local "I'd want Pro" taps from the Saved-tab teaser.
///
/// Pure demand instrumentation for the post-MVP Pro decision: it answers
/// "does anyone want this?" alongside the session log that answers "is the
/// recurrence real?" (see `Docs/pattern_detection_spec.md`, Phasing / MVP
/// boundary). No account, no email, no network — just a local count + date.
@MainActor
final class ProInterestStore: ObservableObject {
    @Published private(set) var interestCount: Int
    @Published private(set) var lastInterestDate: Date?

    private let defaults: UserDefaults
    private let countKey = "pro_interest_count"
    private let lastDateKey = "pro_interest_last_date"

    /// Whether the user has tapped the teaser at least once.
    var hasRegisteredInterest: Bool { interestCount > 0 }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.interestCount = defaults.integer(forKey: countKey)
        self.lastInterestDate = defaults.object(forKey: lastDateKey) as? Date
    }

    func registerInterest() {
        interestCount += 1
        let now = Date()
        lastInterestDate = now
        defaults.set(interestCount, forKey: countKey)
        defaults.set(now, forKey: lastDateKey)
    }
}
