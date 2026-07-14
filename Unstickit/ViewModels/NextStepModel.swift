import Foundation
import Combine

/// Owns the non-navigation logic for the Next Step screen (S3): the "I'm still stuck"
/// reveal/restart state machine and saving the step. Navigation (resetting the path)
/// and clearing the draft stay in the view, since those are SwiftUI-bound concerns.
@MainActor
final class NextStepModel: ObservableObject {
    let result: NextStepResult
    let brainDump: String

    @Published private(set) var fallbackRevealed = false

    /// Drives the "We'll hold this for tomorrow." confirmation sheet (spec §3).
    @Published var deferConfirmationShown = false
    /// Set once a reminder is scheduled so the sheet can confirm and hide the offer.
    @Published private(set) var reminderScheduled = false

    private let store: RecommendedStepStore
    /// Id of the silently-persisted open-loop session, so it can be resolved when the
    /// user completes ("Got it" → retained) or discards ("Delete & start over" → deleted).
    private var recordedID: UUID?
    /// When the deferred step becomes available again — the moment to remind at.
    private var deferredAvailableOn: Date?

    init(result: NextStepResult, brainDump: String, store: RecommendedStepStore) {
        self.result = result
        self.brainDump = brainDump
        self.store = store
    }

    var nextStep: String { result.nextStep }
    var fallbackStep: String { result.fallbackStep }

    /// Reveals the smaller step inline. Reveal-only — no longer restarts the flow.
    func revealSmallerStep() {
        fallbackRevealed = true
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

    /// "Got it" — the loop is completed. Retain the record (mark it completed) rather
    /// than deleting it, so it accrues into the private on-device archive
    /// (`retain_completed_sessions_spec.md`).
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
