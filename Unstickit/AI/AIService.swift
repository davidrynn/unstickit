import Foundation
import FoundationModels

enum AIServiceError: Error, LocalizedError {
    case modelUnavailable
    case extractionFailed
    case inputTooLong
    case contentRefused
    case clarificationFailed
    case nextStepFailed

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        case .extractionFailed:
            return "Could not analyze your input. Please try again."
        case .inputTooLong:
            return "That's a lot to take in at once. Try trimming it to the few sentences that matter most."
        case .contentRefused:
            return "Some of what you wrote may be sensitive, so it couldn't be analyzed. Try rephrasing it."
        case .clarificationFailed:
            return "Could not generate options. Please try again."
        case .nextStepFailed:
            return "Could not generate your next step. Please try again."
        }
    }

    /// A refusal or over-long input won't succeed on retry — the input itself needs to change.
    var isRetryable: Bool {
        switch self {
        case .contentRefused, .inputTooLong, .modelUnavailable:
            return false
        case .extractionFailed, .clarificationFailed, .nextStepFailed:
            return true
        }
    }
}

/// Which validation gate rejected a Stage-3 candidate step. Logged for diagnostics and used to
/// target the one repair follow-up at the actual problem instead of a generic "try again."
enum StepValidationFailure: String {
    case empty
    case tooLong
    case multiLine
    case tooManyWords
    case multiSentence
    case forbiddenPhrase
    /// Retry-only: the candidate is a near-repeat of the step the user just rejected
    /// (observed: the model returning the rejected sentence with one verb swapped).
    case repeatedRejected
    /// The step names a task artifact (document, spreadsheet, email…) the user never
    /// mentioned — the model assuming a typical setup instead of using their words
    /// (observed: "the planning document", "the business promotion spreadsheet").
    case inventedArtifact
}

/// On-device model availability, mapped to a UI-facing enum so views don't import FoundationModels.
nonisolated enum AIAvailability: Equatable {
    case available
    /// The hardware can't run Apple Intelligence (e.g. pre-iPhone 15 Pro).
    case deviceNotEligible
    /// Eligible hardware, but Apple Intelligence is turned off in Settings.
    case appleIntelligenceNotEnabled
    /// Available but the model is still downloading / warming up.
    case modelNotReady
    /// A reason the framework reports that we don't specifically handle.
    case unknown
}

actor AIService {
    static let shared = AIService()

    private init() {}

    // MARK: - Device Eligibility

    nonisolated func availability() -> AIAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unknown
        }
    }

    nonisolated func isAvailable() -> Bool {
        availability() == .available
    }

    // MARK: - Stage 1: Extraction

    func extract(from brainDump: String) async throws -> ExtractionResult {
        #if DEBUG
        // UI-test hooks (mirror ContentView's UI_BYPASS_AI_GATE), both with a short
        // "thinking" delay: UI_FORCE_EXTRACT_ERROR=1 simulates a processing failure;
        // UI_MOCK_AI=1 returns canned results so the full flow (dump → reflection →
        // next step) can be exercised on simulators without Apple Intelligence.
        if ProcessInfo.processInfo.environment["UI_FORCE_EXTRACT_ERROR"] == "1" {
            try await Task.sleep(for: .seconds(1.5))
            throw AIServiceError.extractionFailed
        }
        if ProcessInfo.processInfo.environment["UI_MOCK_AI"] == "1" {
            try await Task.sleep(for: .seconds(1.5))
            return ExtractionResult(
                isActionable: true,
                clarificationPrompt: nil,
                goalSummary: "You want to make steady progress on your app.",
                blockers: [
                    Blocker(description: "Bugs keep eating the time you set aside.",
                            type: .practical)
                ],
                frictionSummary: "Every session starts with friction instead of momentum.",
                summary: "You want to ship your app, but recurring bugs keep making the next step feel unclear."
            )
        }
        #endif
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIServiceError.modelUnavailable
        }

        let session = LanguageModelSession()
        let prompt = """
        Someone is feeling stuck and has written out what's going on. Read what they shared \
        with care — they may be frustrated, overwhelmed, or unsure where to begin.

        Your job is to help them feel understood, then gently surface what might be getting in \
        their way. Reflect only what they actually wrote — never invent a goal, fear, or blocker \
        they did not describe.

        Analyze their input and produce:
        - goalSummary: A single warm sentence reflecting back what they are trying to accomplish, \
        written as if you genuinely understand why it matters to them. Write in second person.
        - blockers: the blockers they actually described, in plain human language — not \
        clinical labels. 1 to 3, and fewer is better: if they only described one, return only \
        one. NEVER invent a blocker to fill out the list — every blocker must trace back to \
        something they explicitly wrote. Each should feel like something a thoughtful friend \
        would name — how it feels from the inside, not how it looks from outside. \
        Assign each a type: practical (missing resources, access, or skills), \
        informational (unclear path or decision needed), or emotional (fear, avoidance, \
        self-doubt). Most inputs will NOT include all three types — never add a blocker just \
        to cover a missing type.
        - frictionSummary: A single warm sentence that names what is making this genuinely hard — \
        emotionally, practically, or both. Write it with care, not detachment. Use second person.
        - summary: A short second-person display line — one sentence, at most 28 words — that \
        names what they want to accomplish and the friction getting in the way. Plain and direct: \
        no diagnosis, no therapy language, no generic encouragement. \
        Example: "You want to finish your app, but AI/SwiftUI bugs keep making the next step feel unclear."
        - isActionable: true only if they actually described BOTH a concrete goal AND at least \
        one specific blocker, in their own words — never infer or invent either to fill the \
        fields. Vague distress with no concrete goal ("stuck on everything", "can't get anything \
        done") is false; a terse but specific goal ("file my quarterly taxes but haven't tracked \
        expenses") is true. When unsure, false. If false, set clarificationPrompt to a warm, \
        friendly question and do not fabricate the rest.

        User input:
        \(brainDump)
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: ExtractionResult.self
            )
            var result = response.content
            // Contract enforcement in code — the model keeps breaking these in prose:
            // stray newlines in blocker text (rendered as a blank row), near-duplicate
            // blockers, more than 3 blockers, and a display summary stitched from two of
            // its own other fields (two sentences, over the 28-word cap).
            result.blockers = Self.cleanedBlockers(result.blockers)
            if result.blockers.count > 3 {
                result.blockers = Array(result.blockers.prefix(3))
            }
            result.summary = Self.enforcedDisplaySummary(result.summary, goalFallback: result.goalSummary)
            #if DEBUG
            print("""

            ┌─ STAGE 1: EXTRACTION ──────────────────────────────
            │ PROMPT:
            \(prompt.split(separator: "\n").map { "│   " + $0 }.joined(separator: "\n"))
            │
            │ RESULT:
            │   isActionable: \(result.isActionable)
            │   clarificationPrompt: \(result.clarificationPrompt ?? "nil")
            │   goalSummary: \(result.goalSummary)
            │   blockers:
            \(result.blockers.map { "│     [\($0.type.rawValue)] \($0.description)" }.joined(separator: "\n"))
            │   frictionSummary: \(result.frictionSummary)
            │   summary: \(result.summary)
            └────────────────────────────────────────────────────
            """)
            #endif
            return result
        } catch {
            #if DEBUG
            print("⚠️ STAGE 1 extraction error: \(error)")
            #endif
            if let genError = error as? LanguageModelSession.GenerationError {
                switch genError {
                case .refusal:
                    throw AIServiceError.contentRefused
                case .exceededContextWindowSize:
                    // The prompt + guided-generation schema already sit near the model's
                    // 4096-token limit; a long brain dump tips it over. Retrying won't help —
                    // ask the user to shorten it rather than showing a generic failure.
                    throw AIServiceError.inputTooLong
                default:
                    break
                }
            }
            throw AIServiceError.extractionFailed
        }
    }

    /// Trim stray whitespace/newlines from blocker text (observed rendering as a blank
    /// row), drop empties, and drop near-duplicates (≥80% word overlap with an earlier
    /// blocker — catches restatements, not merely related blockers).
    static func cleanedBlockers(_ blockers: [Blocker]) -> [Blocker] {
        var kept: [Blocker] = []
        for var blocker in blockers {
            blocker.description = blocker.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !blocker.description.isEmpty else { continue }
            let isDuplicate = kept.contains {
                wordCoverage(of: blocker.description, in: $0.description) >= 0.8
            }
            if !isDuplicate { kept.append(blocker) }
        }
        return kept
    }

    /// The display summary's contract is one sentence, ≤28 words; the model dodges it two
    /// ways — stitching goalSummary + frictionSummary as two sentences, or comma-splicing
    /// them into one ~50-word sentence. Keep the first sentence; if that still blows the
    /// word budget, prefer the goal summary when it's shorter.
    static func enforcedDisplaySummary(_ summary: String, goalFallback: String? = nil) -> String {
        let display = firstSentence(of: summary)
        let displayWords = display.split(whereSeparator: \.isWhitespace).count
        guard displayWords > 35,
              let goal = goalFallback.map({ firstSentence(of: $0) }),
              !goal.isEmpty,
              goal.split(whereSeparator: \.isWhitespace).count < displayWords else {
            return display
        }
        return goal
    }

    private static func firstSentence(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sentenceCount(trimmed) > 1 else { return trimmed }
        var first: String?
        trimmed.enumerateSubstrings(
            in: trimmed.startIndex..<trimmed.endIndex, options: .bySentences
        ) { substring, _, _, stop in
            if let substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                first = substring.trimmingCharacters(in: .whitespacesAndNewlines)
                stop = true
            }
        }
        return first ?? trimmed
    }

    // MARK: - Stage 2: Clarification Options

    func clarify(extraction: ExtractionResult, brainDump: String) async throws -> ClarificationResult {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UI_MOCK_AI"] == "1" {
            return ClarificationResult(options: [
                ClarificationOption(label: "I keep hitting the same bugs over and over",
                                    mode: .reproduce),
                ClarificationOption(label: "I'm not sure which fix to start with",
                                    mode: .narrow),
                ClarificationOption(label: "It all feels like too much at once",
                                    mode: .clarify),
            ])
        }
        #endif
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIServiceError.modelUnavailable
        }

        // The small on-device model often returns duplicate modes (e.g. clarify ×2,
        // no reproduce), the wrong count, or labels that just parrot the prompt's own
        // example/mode descriptions instead of the user's situation. Normalize to one
        // non-generic option per mode; if a mode is missing or only covered by a generic
        // echo, do one repair reroll. Keep a deduped best-effort set rather than
        // dead-ending (or showing duplicate-mode rows) if the model still misbehaves.
        let first = try await requestClarification(extraction: extraction, brainDump: brainDump)
        if let complete = oneOptionPerMode(first) {
            return complete
        }
        guard let second = try? await requestClarification(extraction: extraction, brainDump: brainDump) else {
            return dedupByMode(first)
        }
        if let complete = oneOptionPerMode(second) {
            return complete
        }
        // Neither attempt produced a full non-generic set — return whichever deduped set is
        // better: more grounded labels first, then more coverage.
        let a = dedupByMode(first)
        let b = dedupByMode(second)
        func score(_ r: ClarificationResult) -> (Int, Int) {
            (r.options.filter { !Self.isGenericOptionLabel($0.label) }.count, r.options.count)
        }
        return score(b) > score(a) ? b : a
    }

    /// Exactly 3 options, one per `StuckMode` in canonical order, or `nil` if any mode is
    /// missing or covered only by a generic prompt-echo label. Drops duplicates and extras.
    private func oneOptionPerMode(_ result: ClarificationResult) -> ClarificationResult? {
        var picked: [ClarificationOption] = []
        for mode in StuckMode.allModes {
            guard let option = result.options.first(where: {
                $0.mode == mode && !Self.isGenericOptionLabel($0.label)
            }) else { return nil }
            picked.append(option)
        }
        return ClarificationResult(options: picked)
    }

    /// Best-effort set when no attempt was complete: one option per covered mode, preferring
    /// a grounded label over a generic echo, but keeping an echo rather than dropping the row
    /// entirely — a generic tappable option still beats a missing one.
    private func dedupByMode(_ result: ClarificationResult) -> ClarificationResult {
        var kept: [ClarificationOption] = []
        for mode in StuckMode.allModes {
            let candidates = result.options.filter { $0.mode == mode }
            if let best = candidates.first(where: { !Self.isGenericOptionLabel($0.label) }) ?? candidates.first {
                kept.append(best)
            }
        }
        return ClarificationResult(options: kept)
    }

    private func requestClarification(extraction: ExtractionResult, brainDump: String) async throws -> ClarificationResult {
        let session = LanguageModelSession()
        let prompt = """
        Someone is stuck. In their own words:

        \(brainDump)

        What you reflected back to them:
        Goal: \(extraction.goalSummary)
        Friction: \(extraction.frictionSummary)

        Generate exactly 3 short options that describe how they might be feeling stuck right \
        now — first-person phrases they can tap to identify with. One option for each of the \
        three modes:

        reproduce — they've tried things and nothing has worked
        narrow — they aren't sure where to begin or what the real problem is
        clarify — they feel overwhelmed or scattered

        Every label must mention something specific from their own words — their task, their \
        project, the thing that's wrong — so it could not apply to anyone else. A bare feeling \
        with nothing of theirs in it ("I feel overwhelmed and can't focus") is not acceptable.

        Example of the right shape, for someone stuck on a grant application: "I keep redoing \
        the budget section and it still feels wrong." Write brand-new phrases from their own \
        situation — never reuse this example.
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

    /// True when a Stage-2 option label merely restates the prompt's own example or one of
    /// the mode descriptions instead of referencing the user's situation — a failure observed
    /// in real sessions (all three options came back as near-verbatim prompt text, e.g.
    /// "I feel overwhelmed and can't focus."). Coverage-based rather than containment-based:
    /// an echo often drops a word or two ("or scattered"), so a label counts as generic when
    /// at least 80% of its words appear in one of the known phrases. A label that adds the
    /// user's own nouns dilutes coverage below the threshold and passes.
    static func isGenericOptionLabel(_ label: String) -> Bool {
        genericOptionPhrases.contains { wordCoverage(of: label, in: $0) >= 0.8 }
    }

    /// Fraction of `candidate`'s normalized words that also appear in `reference`. Catches
    /// near-repeats that containment-based echo checks miss (a single swapped word breaks
    /// substring containment but barely moves coverage). Empty candidates count as fully
    /// covered so callers treat them as echoes rather than novel content.
    private static func wordCoverage(of candidate: String, in reference: String) -> Double {
        let tokens = normalizedForComparison(candidate).split(separator: " ")
        guard !tokens.isEmpty else { return 1 }
        let referenceTokens = Set(normalizedForComparison(reference).split(separator: " "))
        let covered = tokens.filter { referenceTokens.contains($0) }.count
        return Double(covered) / Double(tokens.count)
    }

    /// The Stage-2 prompt text the model is known to parrot: the illustrative example (current
    /// and previous wording) and first-person recastings of the three mode descriptions.
    private static let genericOptionPhrases: [String] = [
        "I keep redoing the budget section and it still feels wrong.",
        "I keep trying fixes but nothing works.",
        "I've tried multiple approaches and none have worked.",
        "I've tried things and nothing has worked.",
        "I'm not sure where to begin or what the real cause is.",
        "I feel overwhelmed or scattered and can't focus."
    ]

    // MARK: - Stage 3: Next Step Generation

    func generateNextStep(
        extraction: ExtractionResult,
        selectedMode: StuckMode,
        brainDump: String,
        selectedOptionLabel: String
    ) async throws -> NextStepResult {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UI_MOCK_AI"] == "1" {
            try await Task.sleep(for: .seconds(1.5))
            return NextStepResult(
                nextStep: fallbackStep(for: selectedMode),
                fallbackStep: smallerFallbackStep(for: selectedMode)
            )
        }
        #endif
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw AIServiceError.modelUnavailable
        }

        // Three-rung ladder, most open first (did_this_help_spec.md): free-form generation,
        // then the constrained slot-fill frame (grounded in the user's task — a validation
        // failure on the open pass lands here, not on the canned template), then the
        // deterministic template as the true last resort.
        var source = "generated"
        var step = await generateActivationStep(
            mode: selectedMode,
            brainDump: brainDump,
            summary: extraction.summary,
            optionLabel: selectedOptionLabel
        )
        if step == nil {
            step = await constrainedStep(mode: selectedMode, brainDump: brainDump)
            source = step == nil ? "fallback template" : "assembled frame"
        }
        let result = NextStepResult(
            nextStep: step ?? fallbackStep(for: selectedMode),
            fallbackStep: smallerFallbackStep(for: selectedMode)
        )

        #if DEBUG
        print("""

        ┌─ STAGE 3: NEXT STEP ───────────────────────────────
        │ SELECTED MODE: \(selectedMode.rawValue)
        │ SELECTED OPTION: \(selectedOptionLabel)
        │ SOURCE: \(source)
        │
        │ RESULT:
        │   nextStep: \(result.nextStep)
        │   fallbackStep: \(result.fallbackStep)
        └────────────────────────────────────────────────────
        """)
        #endif

        return result
    }

    /// Regenerate the step after the user answered "Not quite" (did_this_help_spec.md).
    ///
    /// Deliberately NOT free-form: the first pass gets one shot at an open, generated step;
    /// once the user has rejected it, the retry must be incapable of nonsense. The model
    /// only picks two slots (`StepIngredients`) — the task, validated in code against the
    /// user's own words, and its smallest first piece — and the step is assembled from a
    /// deterministic frame. Any failure falls back to the template, so the user always gets
    /// a fresh step rather than an error.
    func regenerateNextStep(
        context: NextStepContext,
        brainDump: String,
        rejectedStep: String,
        feedback: String?
    ) async -> NextStepResult {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UI_MOCK_AI"] == "1" {
            try? await Task.sleep(for: .seconds(1.5))
            return NextStepResult(
                nextStep: "Open the one screen that bothers you most and note the first thing that looks off.",
                fallbackStep: smallerFallbackStep(for: context.mode)
            )
        }
        #endif
        let assembled = await constrainedStep(
            mode: context.mode,
            brainDump: brainDump,
            rejectedStep: rejectedStep,
            feedback: feedback
        )
        let result = NextStepResult(
            nextStep: assembled ?? fallbackStep(for: context.mode),
            fallbackStep: smallerFallbackStep(for: context.mode)
        )
        #if DEBUG
        print("""

        ┌─ STAGE 3: NEXT STEP (RETRY, slot-fill) ────────────
        │ REJECTED: \(rejectedStep)
        │ FEEDBACK: \(feedback ?? "none")
        │ SOURCE: \(assembled == nil ? "fallback template" : "assembled frame")
        │
        │ RESULT:
        │   nextStep: \(result.nextStep)
        └────────────────────────────────────────────────────
        """)
        #endif
        return result
    }

    /// One slot-fill attempt plus one targeted re-pick, assembled into a mode frame.
    /// Returns `nil` if the model can't produce grounded slots — the caller templates.
    /// Used by "Not quite" retries (with the rejected step + correction) and as the
    /// middle rung when first-pass generation fails validation (no rejection context).
    private func constrainedStep(
        mode: StuckMode,
        brainDump: String,
        rejectedStep: String? = nil,
        feedback: String? = nil
    ) async -> String? {
        let session = LanguageModelSession()
        var rejectionLines = ""
        if let rejectedStep {
            rejectionLines = "\n\nThey rejected this suggestion: \"\(rejectedStep)\""
            if let feedback {
                rejectionLines += "\nTheir correction (this overrides anything else you assume): \(feedback)"
            }
        }
        let prompt = """
        Someone is stuck. In their own words:

        \(brainDump)\(rejectionLines)

        Pick the ONE task from their own words that is easiest to start right now, and name \
        its smallest first action — 2 to 8 words starting with a verb, doable in two \
        minutes. Use only what they actually wrote: if their correction says something does \
        not exist or missed the point, do not build on it again.
        """
        // The user's correction counts as their words too — it may introduce the real task.
        let groundingSource = brainDump + " " + (feedback ?? "")

        if let step = await requestStepIngredients(
            session: session, prompt: prompt, mode: mode,
            groundingSource: groundingSource, rejectedStep: rejectedStep
        ) {
            return step
        }
        // One targeted re-pick: name the failure (ungrounded task) rather than rerolling blind.
        return await requestStepIngredients(
            session: session,
            prompt: "That task was not taken from their own words, or repeated the rejected " +
                "suggestion. Pick again, copying the task phrase from what they actually wrote.",
            mode: mode,
            groundingSource: groundingSource,
            rejectedStep: rejectedStep
        )
    }

    /// Ask for slots, validate them in code, and assemble the frame. Returns `nil` when the
    /// slots are ungrounded/malformed or the assembled step trips a validation gate.
    private func requestStepIngredients(
        session: LanguageModelSession,
        prompt: String,
        mode: StuckMode,
        groundingSource: String,
        rejectedStep: String?
    ) async -> String? {
        guard let response = try? await session.respond(
            to: prompt,
            generating: StepIngredients.self,
            options: GenerationOptions(temperature: 0.5)
        ) else { return nil }
        let ingredients = response.content
        guard Self.taskIsGrounded(ingredients.task, in: groundingSource),
              Self.isValidFirstAction(ingredients.firstAction) else {
            #if DEBUG
            print("⚠️ STAGE 3 retry slots rejected. task: \(ingredients.task) | firstAction: \(ingredients.firstAction)")
            #endif
            return nil
        }
        let step = Self.assembleStep(mode: mode, task: ingredients.task, firstAction: ingredients.firstAction)
        guard Self.validationFailure(
            for: step, rejecting: rejectedStep, groundedIn: groundingSource
        ) == nil else { return nil }
        return step
    }

    /// A task slot is usable only if it substantially quotes the user (≥60% of its words
    /// appear in their dump or correction). This is the production guard the free-form
    /// path could never have: a hallucinated task ("the planning document") fails here
    /// deterministically instead of reaching the screen.
    static func taskIsGrounded(_ task: String, in source: String) -> Bool {
        let words = normalizedForComparison(task).split(separator: " ")
        guard (2...10).contains(words.count) else { return false }
        return wordCoverage(of: task, in: source) >= 0.6
    }

    /// The first-action slot is allowed to be generative (it names a move on something
    /// that may not exist yet), but must stay slot-sized: 2–8 words, single line.
    static func isValidFirstAction(_ action: String) -> Bool {
        let trimmed = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n") else { return false }
        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        return (2...8).contains(wordCount)
    }

    /// Deterministic frames, written once in the app's voice. Quoting the task sidesteps
    /// grammatical mismatch with whatever phrase shape the model extracted; the first
    /// action stands as its own sentence, which also normalizes its casing.
    /// No timers, no "then stop" — real-device feedback read those as gimmicky and
    /// patronizing ("Why a timer"), and a fixed frame can't answer that question.
    static func assembleStep(mode: StuckMode, task: String, firstAction: String) -> String {
        let task = task.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .reproduce:
            return "Go back to \u{201C}\(task)\u{201D}. Write down the last thing you tried and what actually happened."
        case .narrow:
            return "Start with \u{201C}\(task)\u{201D}. \(sentenceCased(firstAction))"
        case .clarify:
            return "Pick just one thing: \u{201C}\(task)\u{201D}. \(sentenceCased(firstAction))"
        }
    }

    /// Trim, capitalize the first letter, and end with a single period — the model returns
    /// fragments in unpredictable casing ("Research ballet techniques…").
    private static func sentenceCased(_ phrase: String) -> String {
        var trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix(".") { trimmed = String(trimmed.dropLast()) }
        guard let first = trimmed.first else { return trimmed }
        return first.uppercased() + trimmed.dropFirst() + "."
    }

    /// Best-effort free-form generation of the activation step — first pass only; "Not
    /// quite" retries use the constrained slot-fill path instead (did_this_help_spec.md).
    /// Returns `nil` (so the caller uses a template) on any failure, refusal, or output
    /// that still fails validation after one targeted repair attempt.
    private func generateActivationStep(
        mode: StuckMode,
        brainDump: String,
        summary: String,
        optionLabel: String
    ) async -> String? {
        let session = LanguageModelSession()
        let prompt = """
        Someone is stuck and needs one simple, concrete first action to get moving again.

        Their situation: \(brainDump)
        What you reflected back to them: \(summary)
        How they say they're stuck: "\(optionLabel)"

        \(Self.modeGuidance(mode))

        Write ONE first action for them:
        - The first real move on their actual task — not advice, not a plan, not a reflection \
        on how they feel.
        - Start with an action verb: Open, Write, Find, Pick, Look at.
        - One or two short sentences, at most 30 words total.
        - Name the specific thing from THEIR situation — their form, their file, their phone \
        call — not something generic, and never a document, email, or tool they didn't \
        mention. If the thing they need doesn't exist yet, the first action is to create \
        its smallest first piece (a blank note, a single line), not to open it.
        """
        // No illustrative example: two real sessions showed the model parroting it — once
        // colliding with a user's actual permit task. The @Guide description and the rules
        // above carry the shape; the validation gates catch drift.

        // Lower temperature than the default: trade creativity for instruction-following.
        let attempt = await requestActivationStep(
            session: session, prompt: prompt, temperature: 0.5, groundingSource: brainDump
        )
        switch attempt {
        case .validated(let step):
            return step
        case .error:
            return nil
        case .invalid(let failure):
            // One repair attempt in the same session (so the model keeps the original
            // context) that names the specific gate it tripped, rather than discarding
            // straight to the deterministic template — mirrors Stage 2's `clarify()` repair
            // reroll (`:185-199`).
            guard case .validated(let repaired) = await requestActivationStep(
                session: session,
                prompt: Self.repairPrompt(for: failure),
                temperature: 0.5,
                groundingSource: brainDump
            ) else {
                return nil
            }
            return repaired
        }
    }

    /// Result of one Stage-3 generation attempt.
    private enum StepAttemptResult {
        case validated(String)
        case invalid(StepValidationFailure)
        case error
    }

    private func requestActivationStep(
        session: LanguageModelSession,
        prompt: String,
        temperature: Double,
        rejectedStep: String? = nil,
        groundingSource: String? = nil
    ) async -> StepAttemptResult {
        do {
            let response = try await session.respond(
                to: prompt,
                generating: ActivationStep.self,
                options: GenerationOptions(temperature: temperature)
            )
            let raw = response.content.step
            if let failure = Self.validationFailure(
                for: raw, rejecting: rejectedStep, groundedIn: groundingSource
            ) {
                #if DEBUG
                print("⚠️ STAGE 3 candidate failed validation (\(failure.rawValue)). Raw: \(raw)")
                #endif
                return .invalid(failure)
            }
            return .validated(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            #if DEBUG
            print("⚠️ STAGE 3 generation error (using fallback): \(error)")
            #endif
            return .error
        }
    }

    /// A short, targeted correction for the specific gate that rejected the first attempt —
    /// gives the small on-device model something concrete to fix instead of a generic
    /// "try again," which tends to reproduce the same failure.
    private static func repairPrompt(for failure: StepValidationFailure) -> String {
        let correction: String
        switch failure {
        case .empty:
            correction = "That came back empty."
        case .tooLong, .tooManyWords:
            correction = "That was too long."
        case .multiLine:
            correction = "That had more than one line."
        case .multiSentence:
            correction = "That had more than two sentences — it read like a plan."
        case .forbiddenPhrase:
            correction = "That was too close to a stock example rather than something " +
                "specific to their actual situation."
        case .repeatedRejected:
            correction = "That was the same suggestion they already rejected, barely " +
                "reworded. It must not come back in any form — pick a different thing " +
                "from their situation to act on."
        case .inventedArtifact:
            correction = "That named a document, file, or tool they never mentioned — it " +
                "does not exist. Use only things from their own words, or have them create " +
                "the smallest first piece of the thing (a blank note, a single line)."
        }
        return """
        \(correction) Rewrite it: one concrete first action on their actual task, one or two \
        short sentences, at most 30 words. Still specific to their situation, not generic.
        """
    }

    private static func modeGuidance(_ mode: StuckMode) -> String {
        switch mode {
        case .reproduce:
            return "They've tried things that didn't work. Point them back at the real thing " +
                "with fresh eyes — open it, look at what actually happened, or write down the " +
                "last result they got."
        case .narrow:
            return "They don't know where to begin. Pick the most concrete piece of their task " +
                "and give them its very first move."
        case .clarify:
            return "They're juggling too much at once. Pick the single most pressing task they " +
                "mentioned and give them its very first move."
        }
    }

    /// Accepts a generated step only if it's a short, single, non-empty line. Anything that
    /// looks like a plan (too long, multi-line, numbered list) is rejected so the caller
    /// falls back to a template. Returns the specific gate that failed (rather than just
    /// `nil`) so callers can log the real cause or target a repair at it.
    /// On a "Not quite" retry, `rejecting` carries the step the user rejected: a candidate
    /// that mostly repeats it (≥80% word coverage — catches one-word swaps) is rejected too.
    /// `groundedIn` carries the user's own words (dump + any correction): when present, a
    /// step naming an artifact absent from them is rejected as `.inventedArtifact`.
    static func validationFailure(
        for raw: String,
        rejecting rejectedStep: String? = nil,
        groundedIn source: String? = nil
    ) -> StepValidationFailure? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard trimmed.count <= 280 else { return .tooLong }
        guard !trimmed.contains("\n") else { return .multiLine }
        // The prompt asks for ≤30 words; allow slack to 45 before rejecting as a ramble so a
        // good, on-topic step that runs a little long isn't discarded on length alone. (Tone —
        // e.g. pep talk — can't be checked here; the prompt handles that.)
        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        guard wordCount <= 45 else { return .tooManyWords }
        // Up to two short sentences is a valid step ("Open the form. Gather the first
        // document it asks for."); three or more reads as a plan or a ramble, so reject it
        // and let the repair/fallback path handle it. Uses the locale sentence tokenizer,
        // which keeps abbreviations (e.g. "vs.") intact.
        guard sentenceCount(trimmed) <= 2 else { return .multiSentence }
        // Anti-copy guard: small on-device models sometimes echo an illustrative phrase from
        // the prompt verbatim instead of writing something for the user's actual situation
        // (e.g. a debugging example surfacing for a coffee-newsletter input). Reject only a
        // near-total echo of a known example/placeholder, not any short phrase that merely
        // overlaps one — plain substring containment was too aggressive and could
        // false-positive on legitimate short output.
        let normalized = normalizedForComparison(trimmed)
        for phrase in forbiddenStepPhrases {
            let normalizedPhrase = normalizedForComparison(phrase)
            if isNearTotalEcho(normalized, of: normalizedPhrase) {
                return .forbiddenPhrase
            }
        }
        // Retry-only gate: the user already rejected this step — a near-repeat (observed:
        // same sentence, "review" swapped for "pick") must not come back. Coverage-based,
        // since a one-word swap defeats containment checks.
        if let rejectedStep, wordCoverage(of: trimmed, in: rejectedStep) >= 0.8 {
            return .repeatedRejected
        }
        // Invented-artifact gate: the model may only name a known task artifact if the
        // user's own words (`source`) did first, or as an explicit fresh creation ("a new/
        // blank spreadsheet"). Prompt rules alone did not stop this — the model quotes the
        // instructions' surface rather than following them — so it's enforced here.
        if let source, firstInventedArtifact(in: trimmed, source: source) != nil {
            return .inventedArtifact
        }
        return nil
    }

    /// The first artifact noun in `step` that neither appears in `source` (singular or
    /// plural) nor is introduced as a fresh creation ("new"/"blank"/"fresh" before it), or
    /// `nil` if the step is clean.
    static func firstInventedArtifact(in step: String, source: String) -> String? {
        let sourceTokens = Set(normalizedForComparison(source).split(separator: " ").map(String.init))
        let stepTokens = normalizedForComparison(step).split(separator: " ").map(String.init)
        for (index, token) in stepTokens.enumerated() where artifactNouns.contains(token) {
            let stem = token.hasSuffix("s") ? String(token.dropLast()) : token + "s"
            if sourceTokens.contains(token) || sourceTokens.contains(stem) { continue }
            let previous = index > 0 ? stepTokens[index - 1] : ""
            if ["new", "blank", "fresh"].contains(previous) { continue }
            return token
        }
        return nil
    }

    /// Task artifacts the model invents when it assumes a typical setup for a task type.
    /// Deliberately excludes words that legitimately appear in creation-shaped steps or are
    /// too central to block ("note", "paper", "timer", "application").
    private static let artifactNouns: Set<String> = [
        "document", "documents", "spreadsheet", "spreadsheets", "email", "emails", "inbox",
        "form", "forms", "file", "files", "folder", "folders", "checklist", "checklists",
        "template", "templates", "planner", "calendar", "website", "dashboard", "report",
        "reports", "database", "message", "messages", "portal"
    ]

    /// True if `candidate` and `phrase` are effectively the same text — an exact match, or one
    /// contains the other and the shorter side accounts for at least 80% of the longer side's
    /// word count. A short, legitimate step could coincidentally share a few words with one of
    /// the fixed forbidden phrases; this only rejects a near-total echo, not any overlap.
    private static func isNearTotalEcho(_ candidate: String, of phrase: String) -> Bool {
        guard !candidate.isEmpty, !phrase.isEmpty else { return false }
        if candidate == phrase { return true }
        let longer = candidate.count >= phrase.count ? candidate : phrase
        let shorter = candidate.count >= phrase.count ? phrase : candidate
        guard longer.contains(shorter) else { return false }
        let longerWordCount = longer.split(separator: " ").count
        let shorterWordCount = shorter.split(separator: " ").count
        guard longerWordCount > 0 else { return false }
        return Double(shorterWordCount) / Double(longerWordCount) >= 0.8
    }

    /// Illustrative/placeholder phrases that must never reach the user: the one example in the
    /// Stage-3 prompt, plus canned outputs the model has been seen to regurgitate. Matching is
    /// done on a normalized form (see `normalizedForComparison`), so punctuation/casing
    /// differences in the model's echo are still caught.
    private static let forbiddenStepPhrases: [String] = [
        "Open the permit application and gather the first document it asks for.",
        "Take a few deep breaths and remind yourself that one day at a time is enough.",
        "Make a plan to get back on track."
    ]

    /// Number of sentences in `text`. Uses the locale-aware sentence tokenizer, but first
    /// neutralizes common abbreviations whose internal period the tokenizer would otherwise
    /// treat as a sentence break (e.g. "Substack vs. Ghost" would count as two). Used to
    /// enforce the one-sentence rule on generated steps.
    private static func sentenceCount(_ text: String) -> Int {
        var scrubbed = text
        for abbreviation in ["e.g.", "i.e.", "vs.", "etc.", "Dr.", "Mr.", "Mrs.", "Ms.", "a.m.", "p.m.", "No.", "Inc.", "St."] {
            scrubbed = scrubbed.replacingOccurrences(
                of: abbreviation,
                with: abbreviation.replacingOccurrences(of: ".", with: "")
            )
        }
        var count = 0
        scrubbed.enumerateSubstrings(in: scrubbed.startIndex..<scrubbed.endIndex, options: .bySentences) { substring, _, _, _ in
            if let substring, !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                count += 1
            }
        }
        return count
    }

    /// Lowercases and reduces a string to space-separated alphanumeric tokens so near-identical
    /// echoes (differing only in punctuation, casing, or spacing) compare equal.
    private static func normalizedForComparison(_ string: String) -> String {
        let mapped = string.lowercased().unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(mapped).split(whereSeparator: \.isWhitespace).joined(separator: " ")
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
            return "Write one sentence finishing 'The thing I'm really stuck on is…'"
        }
    }

    /// The even-smaller step kept as the record's fallback text — always deterministic.
    /// (No "then stop" anywhere: telling an already-stuck user to stop read as limiting.)
    private func smallerFallbackStep(for mode: StuckMode) -> String {
        switch mode {
        case .reproduce:
            return "Write one sentence about what you tried."
        case .narrow:
            return "Name the one piece you're least sure about."
        case .clarify:
            return "Write one sentence starting 'I'm stuck because…'"
        }
    }
}
