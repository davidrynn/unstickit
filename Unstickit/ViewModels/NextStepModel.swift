import Foundation
import Combine

/// Owns the non-navigation logic for the Next Step screen (S3): the "Did this help?"
/// regeneration flow (did_this_help_spec.md) and saving the step. Navigation (resetting
/// the path) and clearing the draft stay in the view, since those are SwiftUI-bound
/// concerns.
@MainActor
final class NextStepModel: ObservableObject {
    /// Replaced in place when a "Not quite" regeneration succeeds.
    @Published private(set) var result: NextStepResult
    let brainDump: String

    /// True once "Not quite" is tapped — reveals the optional-feedback field and
    /// "Try again" (or the edit nudge once attempts are used up).
    @Published var feedbackExpanded = false
    /// Optional correction/extra detail folded into the regeneration prompt.
    @Published var feedbackText = ""
    @Published private(set) var regenerationCount = 0

    /// Drives the "We'll hold this for tomorrow." confirmation sheet (spec §3).
    @Published var deferConfirmationShown = false
    /// Set once a reminder is scheduled so the sheet can confirm and hide the offer.
    @Published private(set) var reminderScheduled = false

    /// Past this, another roll of the same input adds no new signal — the UI nudges
    /// toward editing the dump instead (mirrors the reflection screen's reroll nudge).
    static let maxRegenerations = 2
    var canTryAgain: Bool { regenerationCount < Self.maxRegenerations }

    /// Injectable for tests; defaults to the on-device Stage 3 retry, which is
    /// best-effort and never throws (worst case: deterministic template).
    typealias Regenerator = (
        _ context: NextStepContext,
        _ brainDump: String,
        _ rejectedStep: String,
        _ feedback: String?
    ) async -> NextStepResult

    private let context: NextStepContext
    private let regenerator: Regenerator
    private let store: RecommendedStepStore
    /// Id of the silently-persisted open-loop session, so it can be resolved when the
    /// user completes ("Yes" → retained) or discards ("Delete & start over" → deleted).
    private var recordedID: UUID?
    /// When the deferred step becomes available again — the moment to remind at.
    private var deferredAvailableOn: Date?

    init(
        result: NextStepResult,
        brainDump: String,
        context: NextStepContext,
        store: RecommendedStepStore,
        regenerator: Regenerator? = nil
    ) {
        self.result = result
        self.brainDump = brainDump
        self.context = context
        self.store = store
        self.regenerator = regenerator ?? { context, brainDump, rejectedStep, feedback in
            await AIService.shared.regenerateNextStep(
                context: context,
                brainDump: brainDump,
                rejectedStep: rejectedStep,
                feedback: feedback
            )
        }
    }

    var nextStep: String { result.nextStep }

    /// "Not quite" → "Try again": regenerate with the rejected step and the user's
    /// optional correction, replace the step in place, and re-record the open-loop
    /// record so what's persisted matches what's on screen.
    func tryAgain() async {
        guard canTryAgain else { return }
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        let regenerated = await regenerator(
            context,
            brainDump,
            result.nextStep,
            trimmed.isEmpty ? nil : trimmed
        )
        result = regenerated
        regenerationCount += 1
        feedbackText = ""
        feedbackExpanded = false
        rerecordSession()
    }

    /// Silently persist this session as an open loop the moment the step appears —
    /// no user-facing "save". Idempotent across re-appears.
    func recordSession() {
        guard recordedID == nil else { return }
        recordedID = store.recordSession(
            text: result.nextStep,
            fallbackText: result.fallbackStep,
            brainDump: brainDump
        )
    }

    /// A regeneration replaced the step: drop the record made for the rejected step and
    /// record the current one, so completion/deferral always resolve the visible step.
    private func rerecordSession() {
        guard let id = recordedID else { return }
        store.delete(id: id)
        recordedID = nil
        recordSession()
    }

    /// "Yes" (Did this help?) — the loop is completed. Retain the record (mark it
    /// completed) rather than deleting it, so it accrues into the private on-device
    /// archive (`retain_completed_sessions_spec.md`).
    func completeSession() {
        recordedID.map { store.complete(id: $0) }
        recordedID = nil
    }

    /// "Delete & start over" (and the come-back-tomorrow hand-off) — discard the
    /// open-loop record. On defer, the separate deferred record supersedes it.
    func discardSession() {
        recordedID.map { store.delete(id: $0) }
        recordedID = nil
    }

    /// Defers the step to tomorrow (come_back_tomorrow_spec.md §6) and shows the
    /// confirmation. The active draft is cleared by the view.
    func comeBackTomorrow() {
        deferredAvailableOn = store.deferUntilTomorrow(
            text: result.nextStep,
            fallbackText: result.fallbackStep,
            brainDump: brainDump
        )
        deferConfirmationShown = true
    }

    /// Optional reminder for the deferred step (§8). Non-blocking: a denial just
    /// means no reminder — the in-app return card still surfaces the step.
    func setReminder() async {
        guard let deferredAvailableOn else { return }
        let scheduled = await DeferredReminder.schedule(at: deferredAvailableOn)
        reminderScheduled = scheduled
    }
}
