import Foundation
import Combine

/// Append-only local history of resolved sessions (see `Docs/session_log_spec.md`).
///
/// Unlike `RecommendedStepStore`, this never edits, deletes, or expires entries — it is a
/// permanent on-device log. It surfaces nothing to the user; its sole job is to accrue the
/// subject-recurrence evidence that gates the post-MVP Pro decision (ADR 0004). No account,
/// no network — a JSON-`Codable` array in `UserDefaults`, matching the other stores.
@MainActor
final class SessionLogStore: ObservableObject {
    @Published private(set) var entries: [SessionLogEntry] = []

    private let defaults: UserDefaults
    private let storageKey = "session_log"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Append one entry for a resolved session. Callers pass the raw dump; the snippet is
    /// truncated here so no full dump or reflected text is ever stored.
    func record(brainDump: String, chosenMode: StuckMode, blockerTypes: [BlockerType]) {
        entries.append(
            SessionLogEntry(
                brainDumpSnippet: SessionLogEntry.snippet(from: brainDump),
                chosenMode: chosenMode,
                blockerTypes: blockerTypes
            )
        )
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            entries = try JSONDecoder().decode([SessionLogEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to encode session log")
        }
    }
}
