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
    @Published private(set) var rerollCount = 0
    @Published private(set) var generatedStep: NextStepResult?
    @Published var errorMessage: String?
    /// Guards against a second AI call while one is in flight (e.g. a double-tap).
    @Published private(set) var isBusy = false

    private let extraction: ExtractionResult
    private let brainDump: String
    /// Shared loader state. The model sets it for its own work; whether it clears on
    /// success depends on whether a navigation follows (see `run(clearLoaderOnSuccess:)`).
    private let nav: AppNavigation
    /// Append-only evidence log written once when this session resolves (see
    /// `Docs/session_log_spec.md`).
    private let sessionLog: SessionLogStore
    private var workTask: Task<Void, Never>?
    /// Guards the one-entry-per-resolved-session rule: this model instance is one session's
    /// reflection, so we log at most once even if the user pops back and picks again.
    private var didRecordSession = false

    init(
        extraction: ExtractionResult,
        clarification: ClarificationResult?,
        brainDump: String,
        nav: AppNavigation,
        sessionLog: SessionLogStore
    ) {
        self.extraction = extraction
        self.options = clarification?.options ?? []
        self.optionsFailed = (clarification == nil)
        self.brainDump = brainDump
        self.nav = nav
        self.sessionLog = sessionLog
    }

    /// Generate the next step for the chosen option, carrying its `StuckMode` and the
    /// option's wording forward so Stage 3 can ground the step in the user's situation.
    /// Publishes the result to `generatedStep`; the view observes it to navigate. The
    /// loader is *not* cleared on success here — `NextStepView.onAppear` clears it once
    /// the next screen is on-screen, so the loader stays up through the transition.
    func select(_ option: ClarificationOption) {
        run(message: "Generating your next step...", clearLoaderOnSuccess: false) {
            self.generatedStep = try await AIService.shared.generateNextStep(
                extraction: self.extraction,
                selectedMode: option.mode,
                brainDump: self.brainDump,
                selectedOptionLabel: option.label
            )
            self.recordResolvedSession(chosenMode: option.mode)
        }
    }

    /// Append one session-log entry the first time this session produces a next step.
    /// Called only on a successful Stage 3 generation (this is "resolved"); the guard keeps
    /// it to one entry per session even across pop-back-and-retry within this screen.
    private func recordResolvedSession(chosenMode: StuckMode) {
        guard !didRecordSession else { return }
        didRecordSession = true
        sessionLog.record(
            brainDump: brainDump,
            chosenMode: chosenMode,
            blockerTypes: extraction.blockers.map(\.type)
        )
    }

    /// Regenerate a fresh set of 3 options from the same situation — no typed input.
    /// Rerolling adds no new signal, so after one pass the view nudges toward
    /// **Edit what I wrote** (driven by `rerollCount`). Stays on this screen, so the
    /// loader clears on success.
    func somethingElse() {
        run(message: "Finding other options...", clearLoaderOnSuccess: true) {
            let result = try await AIService.shared.clarify(extraction: self.extraction)
            self.options = result.options
            self.optionsFailed = false
            self.rerollCount += 1
        }
    }

    /// Retry the initial option load after a clarification failure (T7). Stays on this
    /// screen, so the loader clears on success.
    func retryOptions() {
        run(message: "Finding your options...", clearLoaderOnSuccess: true) {
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

    /// Run one guarded AI operation behind the shared loader. On failure the loader is
    /// always cleared (the user stays here with an error). On success it is cleared only
    /// when no navigation follows; otherwise the destination clears it on appear.
    private func run(
        message: String,
        clearLoaderOnSuccess: Bool,
        _ operation: @escaping () async throws -> Void,
        onError: @escaping () -> Void = {}
    ) {
        guard !isBusy else { return }
        isBusy = true
        nav.loadingMessage = message
        errorMessage = nil
        workTask = Task {
            do {
                try await operation()
                if clearLoaderOnSuccess { nav.loadingMessage = nil }
            } catch {
                errorMessage = error.localizedDescription
                onError()
                nav.loadingMessage = nil
            }
            isBusy = false
        }
    }
}
