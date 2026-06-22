import Foundation

enum RecommendedStepSource: String, Codable {
    case nextStep
    case fallbackStep
    case deferredTomorrow
}

enum RecommendedStepStatus: String, Codable {
    case active
    case dismissed
}

struct RecommendedStep: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let fallbackText: String?
    let source: RecommendedStepSource
    let originalBrainDump: String?
    let createdAt: Date
    var availableOn: Date?
    var expiresAt: Date?
    var status: RecommendedStepStatus
    var isSaved: Bool

    var isDeferred: Bool {
        source == .deferredTomorrow
    }

    var issueSummary: String {
        guard let originalBrainDump else { return "Saved step" }

        let collapsed = originalBrainDump
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !collapsed.isEmpty else { return "Saved step" }

        let limit = 84
        if collapsed.count <= limit {
            return collapsed
        }

        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
