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

    private let store: RecommendedStepStore
    private var stillStuckCount = 0

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
}
