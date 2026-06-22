import Foundation
import FoundationModels

enum AIServiceError: Error, LocalizedError {
    case modelUnavailable
    case extractionFailed
    case contentRefused
    case clarificationFailed
    case nextStepFailed

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        case .extractionFailed:
            return "Could not analyze your input. Please try again."
        case .contentRefused:
            return "Some of what you wrote may be sensitive, so it couldn't be analyzed. Try rephrasing it."
        case .clarificationFailed:
            return "Could not generate options. Please try again."
        case .nextStepFailed:
            return "Could not generate your next step. Please try again."
        }
    }

    /// A refusal won't succeed on retry — the input itself needs to change.
    var isRetryable: Bool {
        switch self {
        case .contentRefused, .modelUnavailable:
            return false
        case .extractionFailed, .clarificationFailed, .nextStepFailed:
            return true
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
        written as if you genuinely understand why it matters to them. Write in second person.
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
        insight, not a restatement of what they said. Do NOT rephrase what the user said. \
        Surface something that helps explain *why* — a pattern, tension, or dynamic they didn't name. \
        For example: name a loop, a gap between intention and action, or what the repeated behavior reveals.
        - summary: A short second-person display line — one sentence, at most 28 words — that \
        names what they want to accomplish and the friction getting in the way. Plain and direct: \
        no diagnosis, no therapy language, no generic encouragement. \
        Example: "You want to finish your app, but AI/SwiftUI bugs keep making the next step feel unclear."
        - isActionable: true only if the input describes a specific situation with enough detail \
        to identify a goal and at least one blocker. Single words, sentence fragments, or inputs \
        with no described context should return false. \
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
            │   summary: \(result.summary)
            └────────────────────────────────────────────────────
            """)
            return result
            #else
            return response.content
            #endif
        } catch {
            #if DEBUG
            print("⚠️ STAGE 1 extraction error: \(error)")
            #endif
            if let genError = error as? LanguageModelSession.GenerationError,
               case .refusal = genError {
                throw AIServiceError.contentRefused
            }
            throw AIServiceError.extractionFailed
        }
    }

    // MARK: - Stage 2: Clarification Options

    func clarify(extraction: ExtractionResult) async throws -> ClarificationResult {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIServiceError.modelUnavailable
        }

        // The small on-device model often returns duplicate modes (e.g. clarify ×2,
        // no reproduce) or the wrong count, which violates the "exactly 3, one per
        // StuckMode" contract (spec §6). Normalize to one option per mode; if a mode is
        // missing, do one repair reroll. Keep a deduped best-effort set rather than
        // dead-ending (or showing duplicate-mode rows) if the model still misbehaves.
        let first = try await requestClarification(extraction: extraction)
        if let complete = oneOptionPerMode(first) {
            return complete
        }
        guard let second = try? await requestClarification(extraction: extraction) else {
            return dedupByMode(first)
        }
        if let complete = oneOptionPerMode(second) {
            return complete
        }
        // Neither attempt covered all three modes — return whichever deduped set has more.
        let a = dedupByMode(first)
        let b = dedupByMode(second)
        return b.options.count > a.options.count ? b : a
    }

    /// Exactly 3 options, one per `StuckMode` in canonical order, or `nil` if any mode
    /// is missing. Drops duplicates and extras.
    private func oneOptionPerMode(_ result: ClarificationResult) -> ClarificationResult? {
        var picked: [ClarificationOption] = []
        for mode in StuckMode.allModes {
            guard let option = result.options.first(where: { $0.mode == mode }) else { return nil }
            picked.append(option)
        }
        return ClarificationResult(options: picked)
    }

    /// Keep the first option for each mode, so no two rows share a `StuckMode` even when
    /// the set is incomplete (1–2 options).
    private func dedupByMode(_ result: ClarificationResult) -> ClarificationResult {
        var seen = Set<StuckMode>()
        let kept = result.options.filter { seen.insert($0.mode).inserted }
        return ClarificationResult(options: kept)
    }

    private func requestClarification(extraction: ExtractionResult) async throws -> ClarificationResult {
        let session = LanguageModelSession()
        let prompt = """
        Based on this stuck situation, generate exactly 3 short options that describe \
        how the user might be feeling stuck right now.

        Each option must be a short first-person phrase the user can tap to identify with \
        (e.g. "I keep trying fixes but nothing works").
        Each option must be specific to this situation — not generic.
        Do NOT copy blocker text. Write new phrases that feel natural to say aloud. \
        The blocker context is for understanding only — the options must be original.
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
        selectedMode: StuckMode,
        brainDump: String,
        selectedOptionLabel: String
    ) async throws -> NextStepResult {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIServiceError.modelUnavailable
        }

        // Generate the step from the user's own words + the option they chose. The small
        // on-device model is unreliable, so this is best-effort: if it throws, refuses, or
        // returns something that doesn't pass validation, fall back to a deterministic,
        // domain-neutral template for the mode. The worst case equals the old behavior.
        let generated = await generateActivationStep(
            mode: selectedMode,
            brainDump: brainDump,
            summary: extraction.summary,
            optionLabel: selectedOptionLabel
        )
        let nextStep = generated ?? fallbackStep(for: selectedMode)
        let result = NextStepResult(
            nextStep: nextStep,
            fallbackStep: smallerFallbackStep(for: selectedMode)
        )

        #if DEBUG
        print("""

        ┌─ STAGE 3: NEXT STEP ───────────────────────────────
        │ SELECTED MODE: \(selectedMode.rawValue)
        │ SOURCE: \(generated == nil ? "fallback template" : "generated")
        │
        │ RESULT:
        │   nextStep: \(result.nextStep)
        │   fallbackStep: \(result.fallbackStep)
        └────────────────────────────────────────────────────
        """)
        #endif

        return result
    }

    /// Best-effort generation of the activation step. Returns `nil` (so the caller uses a
    /// template) on any failure, refusal, or output that fails validation.
    private func generateActivationStep(
        mode: StuckMode,
        brainDump: String,
        summary: String,
        optionLabel: String
    ) async -> String? {
        let session = LanguageModelSession()
        let prompt = """
        Someone is stuck and has chosen how they feel stuck. Give them ONE tiny next \
        action — something concrete they can do in about two minutes that gets them moving. \
        It is a starting nudge, not a plan or a solution.

        Their situation: \(brainDump)
        What you reflected back to them: \(summary)
        How they say they're stuck: "\(optionLabel)"

        Match the action to this kind of stuckness:
        \(Self.modeGuidance(mode))

        Rules:
        - Begin with a concrete action verb: Write, List, Open, Pick, Find, Put, Set a timer, \
        Look at. The step must be a physical, observable action — NOT a feeling, a mindset, or \
        reassurance.
        - One single sentence, at most 25 words.
        - Concrete and specific to THEIR situation — use their domain, not generic advice.
        - Intentionally incomplete: surface the real friction or a starting point; do not \
        try to solve the whole thing.
        - No therapy language, no pep talk, no "remind yourself", no numbered steps.

        Examples of the right shape (different situations):
        GOOD: "Write down the three job titles you'd actually be glad to get, then stop."
        GOOD: "Set a timer for two minutes and put away only the things on the garage floor."
        GOOD: "Open the file where the error happens and read just the first function."
        BAD: "Take a few deep breaths and remind yourself that one day at a time is enough." \
        (this is reassurance, not an action — never do this)
        BAD: "Make a plan to get back on track." (too big, not concrete)
        """

        let step: String?
        do {
            let response = try await session.respond(to: prompt, generating: ActivationStep.self)
            step = Self.validatedStep(response.content.step)
        } catch {
            #if DEBUG
            print("⚠️ STAGE 3 generation error (using fallback): \(error)")
            #endif
            step = nil
        }
        return step
    }

    private static func modeGuidance(_ mode: StuckMode) -> String {
        switch mode {
        case .reproduce:
            return "They've tried things that didn't work. Have them capture what they already " +
                "tried, or what actually happened, so the real problem becomes visible."
        case .narrow:
            return "They don't know where to begin. Have them pick one small, specific piece to " +
                "look at or name — shrink the scope to a single concrete thing."
        case .clarify:
            return "They feel overwhelmed and scattered. Have them name, in one sentence, the " +
                "single thing they're most stuck on right now."
        }
    }

    /// Accepts a generated step only if it's a short, single, non-empty line. Anything that
    /// looks like a plan (too long, multi-line, numbered list) is rejected so the caller
    /// falls back to a template.
    private static func validatedStep(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 240 else { return nil }
        guard !trimmed.contains("\n") else { return nil }
        // The prompt asks for ≤25 words; reject anything well past that as a plan/ramble
        // so it falls back to the template. (Tone — e.g. pep talk — can't be checked here;
        // the prompt's few-shot handles that.)
        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        guard wordCount <= 30 else { return nil }
        return trimmed
    }

    // MARK: - Deterministic fallbacks (no model, domain-neutral)

    /// Safe primary step when generation is unavailable. Noun-free so it reads correctly for
    /// any situation (job search, garage, code, taxes), unlike the old phrase-slotting.
    private func fallbackStep(for mode: StuckMode) -> String {
        switch mode {
        case .reproduce:
            return "Write down the last thing you tried and what actually happened — just a sentence or two."
        case .narrow:
            return "Pick the one part of this that feels least clear, and write a sentence about just that."
        case .clarify:
            return "Write one sentence finishing 'The thing I'm really stuck on is…' and then stop."
        }
    }

    /// The even-smaller step revealed by "I'm still stuck" — always deterministic.
    private func smallerFallbackStep(for mode: StuckMode) -> String {
        switch mode {
        case .reproduce:
            return "Write one sentence about what you tried, then stop."
        case .narrow:
            return "Name the one piece you're least sure about, then stop."
        case .clarify:
            return "Write 'I'm stuck because…' and stop."
        }
    }
}
