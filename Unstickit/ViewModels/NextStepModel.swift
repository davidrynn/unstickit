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
    @Published private(set) var confirmationMessage: String?

    /// Drives the "We'll hold this for tomorrow." confirmation sheet (spec §3).
    @Published var deferConfirmationShown = false
    /// Set once a reminder is scheduled so the sheet can confirm and hide the offer.
    @Published private(set) var reminderScheduled = false

    private let store: RecommendedStepStore
    private var stillStuckCount = 0
    /// When the deferred step becomes available again — the moment to remind at.
    private var deferredAvailableOn: Date?

    init(result: NextStepResult, brainDump: String, store: RecommendedStepStore) {
        self.result = result
        self.brainDump = brainDump
        self.store = store
    }

    var nextStep: String { result.nextStep }
    var fallbackStep: String { result.fallbackStep }

    /// First tap reveals the smaller step inline (returns `true`). A later tap returns
    /// `false`, signalling the caller to restart from the brain dump.
    func registerStillStuck() -> Bool {
        stillStuckCount += 1
        if stillStuckCount == 1 {
            fallbackRevealed = true
            return true
        }
        return false
    }

    func saveForLater() {
        store.saveStep(text: result.nextStep, fallbackText: result.fallbackStep, brainDump: brainDump)
        confirmationMessage = "Saved."
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
