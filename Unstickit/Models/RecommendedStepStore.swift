import Foundation
import Combine

@MainActor
final class RecommendedStepStore: ObservableObject {
    @Published private(set) var steps: [RecommendedStep] = []
    /// When the user last viewed the Saved tab. Saved steps created after this are
    /// "unseen" and drive the tab badge, so the badge reads as a notification that
    /// clears on view rather than a permanent total.
    @Published private(set) var lastSeenSavedAt: Date

    private let defaults: UserDefaults
    private let storageKey = "recommended_steps"
    private let lastSeenSavedKey = "saved_tab_last_seen_at"
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        // Default to distantPast so any pre-existing saved steps still badge until
        // the user first opens the Saved tab (preserves the prior behavior up to that point).
        self.lastSeenSavedAt = defaults.object(forKey: lastSeenSavedKey) as? Date ?? .distantPast
        load()
        purgeExpired()
    }

    /// Saved steps the user hasn't seen yet — the value shown on the Saved tab badge.
    var unseenSavedCount: Int {
        savedSteps.filter { $0.createdAt > lastSeenSavedAt }.count
    }

    /// Mark the Saved tab as viewed, clearing the badge. Called when the tab is opened.
    func markSavedSeen() {
        let now = Date()
        guard now > lastSeenSavedAt else { return }
        lastSeenSavedAt = now
        defaults.set(now, forKey: lastSeenSavedKey)
    }

    var activeSteps: [RecommendedStep] {
        steps
            .filter { $0.status == .active }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var hasActiveSteps: Bool {
        !activeSteps.isEmpty
    }

    /// Intentionally saved steps only — drives the Saved tab badge.
    var savedSteps: [RecommendedStep] {
        steps
            .filter { $0.status == .active && $0.isSaved }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var dueDeferredStep: RecommendedStep? {
        let now = Date()
        return steps
            .filter {
                $0.status == .active &&
                $0.source == .deferredTomorrow &&
                ($0.availableOn ?? $0.createdAt) <= now
            }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    func saveStep(text: String, fallbackText: String? = nil, brainDump: String? = nil) {
        let now = Date()
        addStep(
            text: text,
            fallbackText: fallbackText,
            source: .nextStep,
            brainDump: brainDump,
            createdAt: now,
            availableOn: nil,
            expiresAt: nil,
            isSaved: true
        )
    }

    func saveFallbackStep(text: String, brainDump: String? = nil) {
        let now = Date()
        addStep(
            text: text,
            fallbackText: nil,
            source: .fallbackStep,
            brainDump: brainDump,
            createdAt: now,
            availableOn: nil,
            expiresAt: nil,
            isSaved: true
        )
    }

    /// Silently persist a session as an open loop — history, not an intentional
    /// "save" (`isSaved` stays false, so it never inflates the Saved badge). Returns
    /// the record's id so the caller can remove it once the loop is closed. Reuses an
    /// existing active record with the same step text rather than duplicating.
    @discardableResult
    func recordSession(text: String, fallbackText: String?, brainDump: String) -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let existing = steps.first(where: {
            $0.status == .active && $0.text.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return existing.id
        }

        let step = RecommendedStep(
            id: UUID(),
            text: trimmed,
            fallbackText: fallbackText?.trimmingCharacters(in: .whitespacesAndNewlines),
            source: .nextStep,
            originalBrainDump: brainDump,
            createdAt: Date(),
            availableOn: nil,
            expiresAt: nil,
            status: .active,
            isSaved: false
        )
        steps.append(step)
        save()
        return step.id
    }

    /// Remove a session by id — used when an open loop is completed or discarded.
    func delete(id: UUID) {
        guard steps.contains(where: { $0.id == id }) else { return }
        steps.removeAll { $0.id == id }
        save()
    }

    /// Defers the step to tomorrow and returns when it becomes available again,
    /// so callers can schedule an optional reminder for that moment.
    @discardableResult
    func deferUntilTomorrow(text: String, fallbackText: String?, brainDump: String) -> Date {
        let now = Date()
        let availableOn = Self.nextTomorrowAvailability(from: now, calendar: calendar)
        addStep(
            text: text,
            fallbackText: fallbackText,
            source: .deferredTomorrow,
            brainDump: brainDump,
            createdAt: now,
            availableOn: availableOn,
            expiresAt: calendar.date(byAdding: .day, value: 7, to: now),
            isSaved: false
        )
        return availableOn
    }

    func dismiss(_ step: RecommendedStep) {
        steps.removeAll { $0.id == step.id }
        save()
    }

    func save(_ step: RecommendedStep) {
        update(step) { item in
            item.isSaved = true
            item.expiresAt = nil
        }
    }

    func unsave(_ step: RecommendedStep) {
        let expiration = calendar.date(byAdding: .day, value: 7, to: step.createdAt)
        update(step) { item in
            item.isSaved = false
            item.expiresAt = expiration
        }
        purgeExpired()
    }

    func purgeExpired() {
        let now = Date()
        let filtered = steps.filter { step in
            guard !step.isSaved, let expiresAt = step.expiresAt else { return true }
            return expiresAt > now
        }

        let unsavedActive = filtered
            .filter { !$0.isSaved && $0.status == .active }
            .sorted { $0.createdAt > $1.createdAt }

        let keepUnsavedIDs = Set(unsavedActive.prefix(20).map(\.id))
        let purgedSteps = filtered.filter { $0.isSaved || $0.status != .active || keepUnsavedIDs.contains($0.id) }
        guard purgedSteps != steps else { return }

        steps = purgedSteps
        save()
    }

    static func nextTomorrowAvailability(from date: Date, calendar: Calendar = .current) -> Date {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let fiveAM = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: nextDay) ?? nextDay
        let sixHoursLater = date.addingTimeInterval(6 * 60 * 60)
        return max(fiveAM, sixHoursLater)
    }

    private func addStep(
        text: String,
        fallbackText: String?,
        source: RecommendedStepSource,
        brainDump: String?,
        createdAt: Date,
        availableOn: Date?,
        expiresAt: Date?,
        isSaved: Bool
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        if let existingIndex = steps.firstIndex(where: {
            $0.status == .active &&
            $0.text.caseInsensitiveCompare(trimmedText) == .orderedSame
        }) {
            steps[existingIndex].isSaved = steps[existingIndex].isSaved || isSaved
            if isSaved {
                steps[existingIndex].expiresAt = nil
            }
            if steps[existingIndex].fallbackText == nil, let fallbackText {
                steps[existingIndex] = RecommendedStep(
                    id: steps[existingIndex].id,
                    text: steps[existingIndex].text,
                    fallbackText: fallbackText,
                    source: steps[existingIndex].source,
                    originalBrainDump: steps[existingIndex].originalBrainDump,
                    createdAt: steps[existingIndex].createdAt,
                    availableOn: steps[existingIndex].availableOn,
                    expiresAt: isSaved ? nil : steps[existingIndex].expiresAt,
                    status: steps[existingIndex].status,
                    isSaved: steps[existingIndex].isSaved
                )
            }
            save()
            return
        }

        steps.append(RecommendedStep(
            id: UUID(),
            text: trimmedText,
            fallbackText: fallbackText?.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source,
            originalBrainDump: brainDump,
            createdAt: createdAt,
            availableOn: availableOn,
            expiresAt: expiresAt,
            status: .active,
            isSaved: isSaved
        ))
        save()
    }

    private func update(_ step: RecommendedStep, mutation: (inout RecommendedStep) -> Void) {
        guard let index = steps.firstIndex(where: { $0.id == step.id }) else { return }
        mutation(&steps[index])
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            steps = try JSONDecoder().decode([RecommendedStep].self, from: data)
        } catch {
            steps = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(steps)
            defaults.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to encode recommended steps")
        }
    }
}
