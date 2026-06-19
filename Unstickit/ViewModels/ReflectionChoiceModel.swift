import Foundation
import Combine

/// Owns the AI state for the Reflection + Choice screen (S2).
///
/// Generation is started only by an explicit user tap and guarded (via `busyMessage`)
/// so a double-tap or a re-render cannot kick off a second call. Nothing runs from
/// `.onAppear`, so returning to this screen (e.g. after a tab switch) never re-analyzes.
/// Extraction + clarification are produced before this screen appears (see T5); if
/// clarification failed, `clarification` is nil and the screen offers a retry (T7).
@MainActor
final class ReflectionChoiceModel: ObservableObject {
    @Published private(set) var options: [ClarificationOption]
    /// True when the option set is missing because clarification generation failed.
    @Published private(set) var optionsFailed: Bool
    /// Non-nil while an AI call is in flight; its value is the loader message.
    @Published private(set) var busyMessage: String?
    @Published private(set) var rerollCount = 0
    @Published private(set) var generatedStep: NextStepResult?
    @Published var errorMessage: String?

    private let extraction: ExtractionResult
    private var workTask: Task<Void, Never>?

    var isBusy: Bool { busyMessage != nil }

    init(extraction: ExtractionResult, clarification: ClarificationResult?) {
        self.extraction = extraction
        self.options = clarification?.options ?? []
        self.optionsFailed = (clarification == nil)
    }

    /// Generate the next step for the chosen option, carrying its `StuckMode` forward.
    /// Publishes the result to `generatedStep`; the view observes it to navigate.
    func select(_ option: ClarificationOption) {
        run(message: "Generating your next step...") {
            self.generatedStep = try await AIService.shared.generateNextStep(
                extraction: self.extraction,
                selectedMode: option.mode
            )
        }
    }

    /// Regenerate a fresh set of 3 options from the same situation — no typed input.
    /// Rerolling adds no new signal, so after one pass the view nudges toward
    /// **Edit what I wrote** (driven by `rerollCount`).
    func somethingElse() {
        run(message: "Finding other options...") {
            let result = try await AIService.shared.clarify(extraction: self.extraction)
            self.options = result.options
            self.optionsFailed = false
            self.rerollCount += 1
        }
    }

    /// Retry the initial option load after a clarification failure (T7).
    func retryOptions() {
        run(message: "Finding your options...") {
            let result = try await AIService.shared.clarify(extraction: self.extraction)
            self.options = result.options
            self.optionsFailed = false
        } onError: {
            self.optionsFailed = true
        }
    }

    /// Clear the one-shot navigation signal once the view has consumed it.
    func clearGeneratedStep() {
        generatedStep = nil
    }

    /// Run one guarded AI operation behind `busyMessage`, surfacing any error.
    private func run(
        message: String,
        _ operation: @escaping () async throws -> Void,
        onError: @escaping () -> Void = {}
    ) {
        guard busyMessage == nil else { return }
        busyMessage = message
        errorMessage = nil
        workTask = Task {
            do {
                try await operation()
            } catch {
                errorMessage = error.localizedDescription
                onError()
            }
            busyMessage = nil
        }
    }
}
