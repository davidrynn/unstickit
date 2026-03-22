import Foundation
import FoundationModels

enum AIServiceError: Error, LocalizedError {
    case modelUnavailable
    case extractionFailed
    case clarificationFailed
    case nextStepFailed

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        case .extractionFailed:
            return "Could not analyze your input. Please try again."
        case .clarificationFailed:
            return "Could not generate options. Please try again."
        case .nextStepFailed:
            return "Could not generate your next step. Please try again."
        }
    }
}

actor AIService {
    static let shared = AIService()

    private init() {}

    // MARK: - Device Eligibility

    nonisolated func isAvailable() -> Bool {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return true
        default:
            return false
        }
    }

    // MARK: - Stage 1: Extraction

    func extract(from brainDump: String) async throws -> ExtractionResult {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIServiceError.modelUnavailable
        }

        let session = LanguageModelSession()
        let prompt = """
        Someone is feeling stuck and has written out what's going on. Read what they shared \
        with care — they may be frustrated, overwhelmed, or unsure where to begin.

        Your job is to help them feel understood, then gently surface what might be getting in their way.

        Analyze their input and produce:
        - goalSummary: A single warm sentence reflecting back what they are trying to accomplish, \
        written as if you genuinely understand why it matters to them.
        - blockers: 1 to 3 blockers written in plain, human language — not clinical labels. \
        Each should feel like something a thoughtful friend would name, not a project manager. \
        Describe how the blocker feels from the inside, not how it looks from the outside. \
        Assign each a type: practical (missing resources, access, or skills), \
        informational (unclear path or decision needed), or emotional (fear, avoidance, self-doubt).
        - frictionSummary: A single warm sentence that names what is making this genuinely hard — \
        emotionally, practically, or both. Write it with care, not detachment. Use second person.
        - whatINoticed: One sentence beginning with "I noticed" or "Something I noticed" that \
        surfaces a specific, non-obvious pattern or tension — something the user may not have named \
        directly but that helps explain why they are stuck. This should feel like a small honest \
        insight, not a restatement of what they said.
        - isActionable: true if this describes a real stuck situation with enough context. \
        If false, set clarificationPrompt to a single warm, friendly question asking for more context.

        User input:
        \(brainDump)
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: ExtractionResult.self
            )
            #if DEBUG
            let result = response.content
            print("""

            ┌─ STAGE 1: EXTRACTION ──────────────────────────────
            │ PROMPT:
            \(prompt.split(separator: "\n").map { "│   " + $0 }.joined(separator: "\n"))
            │
            │ RESULT:
            │   isActionable: \(result.isActionable)
            │   goalSummary: \(result.goalSummary)
            │   blockers:
            \(result.blockers.map { "│     [\($0.type.rawValue)] \($0.description)" }.joined(separator: "\n"))
            │   frictionSummary: \(result.frictionSummary)
            │   whatINoticed: \(result.whatINoticed)
            └────────────────────────────────────────────────────
            """)
            return result
            #else
            return response.content
            #endif
        } catch {
            throw AIServiceError.extractionFailed
        }
    }

    // MARK: - Stage 2: Clarification Options

    func clarify(extraction: ExtractionResult) async throws -> ClarificationResult {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIServiceError.modelUnavailable
        }

        let session = LanguageModelSession()
        let prompt = """
        Based on this stuck situation, generate exactly 3 short options that describe \
        how the user might be feeling stuck right now.

        Each option must be a short first-person phrase the user can tap to identify with \
        (e.g. "I keep trying fixes but nothing works").
        Each option must be specific to this situation — not generic.
        One option must be generated for each of the three modes below:

        reproduce — the user has tried multiple approaches and none have worked
        narrow — the user isn't sure where to begin or what the real cause is
        clarify — the user feels overwhelmed or scattered and can't focus

        Goal: \(extraction.goalSummary)
        Blockers: \(extraction.blockers.map(\.description).joined(separator: ", "))
        Friction: \(extraction.frictionSummary)
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: ClarificationResult.self
            )
            #if DEBUG
            let result = response.content
            print("""

            ┌─ STAGE 2: CLARIFICATION OPTIONS ───────────────────
            │ PROMPT:
            \(prompt.split(separator: "\n").map { "│   " + $0 }.joined(separator: "\n"))
            │
            │ RESULT:
            \(result.options.map { "│   [\($0.mode.rawValue)] \($0.label)" }.joined(separator: "\n"))
            └────────────────────────────────────────────────────
            """)
            return result
            #else
            return response.content
            #endif
        } catch {
            throw AIServiceError.clarificationFailed
        }
    }

    // MARK: - Stage 3: Next Step Generation

    func generateNextStep(
        extraction: ExtractionResult,
        selectedMode: StuckMode
    ) async throws -> NextStepResult {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIServiceError.modelUnavailable
        }

        let phrase = try await extractPhrase(from: extraction)
        let result = makeStep(mode: selectedMode, phrase: phrase)

        #if DEBUG
        print("""

        ┌─ STAGE 3: NEXT STEP ───────────────────────────────
        │ SELECTED MODE: \(selectedMode.rawValue)
        │ EXTRACTED PHRASE: \(phrase)
        │
        │ RESULT:
        │   nextStep: \(result.nextStep)
        │   fallbackStep: \(result.fallbackStep)
        └────────────────────────────────────────────────────
        """)
        #endif

        return result
    }

    // MARK: - Phrase Extraction (internal)

    private func extractPhrase(from extraction: ExtractionResult) async throws -> String {
        let session = LanguageModelSession()
        let prompt = """
        Extract a short 2–4 word noun phrase that names the specific problem.
        Return only the phrase — no punctuation, no explanation.
        Examples: "terrain holes", "login bug", "slow build times", "payment errors"

        Goal: \(extraction.goalSummary)
        Blocker: \(extraction.blockers.first?.description ?? "")
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: ProblemPhrase.self
            )
            #if DEBUG
            print("""

            ┌─ STAGE 3a: PHRASE EXTRACTION ──────────────────────
            │ PROMPT:
            \(prompt.split(separator: "\n").map { "│   " + $0 }.joined(separator: "\n"))
            │
            │ RESULT: \(response.content.phrase)
            └────────────────────────────────────────────────────
            """)
            #endif
            return response.content.phrase
        } catch {
            throw AIServiceError.nextStepFailed
        }
    }

    // MARK: - Template Fill (no model)

    private func makeStep(mode: StuckMode, phrase: String) -> NextStepResult {
        switch mode {
        case .reproduce:
            let steps = [
                "Write down what \(phrase) looked like — just what you remember seeing.",
                "Write the last thing you tried with \(phrase) and what happened.",
                "Describe what you expected versus what actually happened with \(phrase)."
            ]
            return NextStepResult(
                nextStep: steps.randomElement()!,
                fallbackStep: "Write '\(phrase) looks like...' and stop there."
            )
        case .narrow:
            let steps = [
                "Open your project and look at the \(phrase) area for 60 seconds without changing anything.",
                "Write down two places \(phrase) might be coming from.",
                "Find one part of \(phrase) you haven't looked at yet and just look at it."
            ]
            return NextStepResult(
                nextStep: steps.randomElement()!,
                fallbackStep: "Open your project and look at it for 30 seconds."
            )
        case .clarify:
            let steps = [
                "Write: 'I keep getting stuck with \(phrase) because...' and stop after one sentence.",
                "Write down what done would look like for \(phrase).",
                "Write the one question you most need to answer about \(phrase)."
            ]
            return NextStepResult(
                nextStep: steps.randomElement()!,
                fallbackStep: "Write: 'I'm stuck because...' and stop."
            )
        }
    }
}
