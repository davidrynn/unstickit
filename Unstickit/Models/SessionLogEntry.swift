import Foundation

/// One resolved session, written append-only on reaching the Next Step screen with a
/// generated step. Deliberately dumb — a handful of fields, no aggregation, no surfaces
/// (see `Docs/session_log_spec.md`). It accrues the subject-recurrence evidence that gates
/// the post-MVP Pro feature (`Docs/pattern_detection_spec.md`, ADR 0004); nothing here is
/// shown to the user.
struct SessionLogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    /// Truncated snippet of the original dump — the only free-text field. It never leaves
    /// the device (ADR 0001); it exists so the future recurrence engine has a human-readable
    /// subject to key on. No reflected summary or next-step text is stored.
    let brainDumpSnippet: String
    let chosenMode: StuckMode
    let blockerTypes: [BlockerType]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        brainDumpSnippet: String,
        chosenMode: StuckMode,
        blockerTypes: [BlockerType]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.brainDumpSnippet = brainDumpSnippet
        self.chosenMode = chosenMode
        self.blockerTypes = blockerTypes
    }

    /// Collapse whitespace and cap length, mirroring `RecommendedStep.issueSummary`, so the
    /// log stores a short subject rather than the full dump.
    static func snippet(from brainDump: String) -> String {
        let collapsed = brainDump
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !collapsed.isEmpty else { return "" }

        let limit = 84
        if collapsed.count <= limit {
            return collapsed
        }

        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
