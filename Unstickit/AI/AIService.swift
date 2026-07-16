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
            // Defensive cap: the prompt asks for 1–3 blockers, but the model
            // occasionally returns 4+ on multi-goal inputs. Clamp so the UI and
            // Stage 2 never see more than the spec allows.
            if result.blockers.count > 3 {
                result.blockers = Array(result.blockers.prefix(3))
            }
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
        let tokens = normalizedForComparison(label).split(separator: " ")
        guard !tokens.isEmpty else { return true }
        for phrase in genericOptionPhrases {
            let phraseTokens = Set(normalizedForComparison(phrase).split(separator: " "))
            let covered = tokens.filter { phraseTokens.contains($0) }.count
            if Double(covered) / Double(tokens.count) >= 0.8 { return true }
        }
        return false
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
        │ SELECTED OPTION: \(selectedOptionLabel)
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

    /// Regenerate the step after the user answered "Not quite" (did_this_help_spec.md).
    /// The rejected step — and the user's optional correction, which overrides anything
    /// previously inferred — are folded into the prompt. Best-effort like
    /// `generateNextStep`: any failure falls back to the deterministic template, so the
    /// user always gets a fresh step rather than an error.
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
        let generated = await generateActivationStep(
            mode: context.mode,
            brainDump: brainDump,
            summary: context.summary,
            optionLabel: context.optionLabel,
            rejection: (step: rejectedStep, feedback: feedback)
        )
        let result = NextStepResult(
            nextStep: generated ?? fallbackStep(for: context.mode),
            fallbackStep: smallerFallbackStep(for: context.mode)
        )
        #if DEBUG
        print("""

        ┌─ STAGE 3: NEXT STEP (RETRY) ───────────────────────
        │ REJECTED: \(rejectedStep)
        │ FEEDBACK: \(feedback ?? "none")
        │ SOURCE: \(generated == nil ? "fallback template" : "generated")
        │
        │ RESULT:
        │   nextStep: \(result.nextStep)
        └────────────────────────────────────────────────────
        """)
        #endif
        return result
    }

    /// Best-effort generation of the activation step. Returns `nil` (so the caller uses a
    /// template) on any failure, refusal, or output that still fails validation after one
    /// targeted repair attempt. `rejection` carries a previously rejected step (plus the
    /// user's optional correction) on a "Not quite" retry.
    private func generateActivationStep(
        mode: StuckMode,
        brainDump: String,
        summary: String,
        optionLabel: String,
        rejection: (step: String, feedback: String?)? = nil
    ) async -> String? {
        let session = LanguageModelSession()
        var rejectionBlock = ""
        if let rejection {
            let feedbackLine = rejection.feedback.map {
                " They corrected you: \"\($0)\" — their correction overrides anything you inferred before."
            } ?? ""
            rejectionBlock = """


            You already suggested: "\(rejection.step)" — they said it did not help.\(feedbackLine) \
            Write a completely different first action; do not repeat or rephrase that suggestion.
            """
        }
        let prompt = """
        Someone is stuck and needs one simple, concrete first action to get moving again.

        Their situation: \(brainDump)
        What you reflected back to them: \(summary)
        How they say they're stuck: "\(optionLabel)"\(rejectionBlock)

        \(Self.modeGuidance(mode))

        Write ONE first action for them:
        - The first real move on their actual task — not advice, not a plan, not a reflection \
        on how they feel.
        - Start with an action verb: Open, Write, Find, Pick, Set a timer, Look at.
        - One or two short sentences, at most 30 words total.
        - Name the specific thing from THEIR situation — their form, their file, their phone \
        call — not something generic.

        Example of the right shape, for someone putting off a permit application: "Open the \
        permit application and gather the first document it asks for." Write brand-new words \
        for their situation — never reuse this example.
        """

        switch await requestActivationStep(session: session, prompt: prompt) {
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
                prompt: Self.repairPrompt(for: failure)
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
        prompt: String
    ) async -> StepAttemptResult {
        do {
            // Lower temperature than the default: Stage 3 fights rambling, multi-sentence
            // output with validation gates + a repair reroll, so trade creativity for
            // instruction-following on the first attempt.
            let response = try await session.respond(
                to: prompt,
                generating: ActivationStep.self,
                options: GenerationOptions(temperature: 0.5)
            )
            let raw = response.content.step
            if let failure = Self.validationFailure(for: raw) {
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
    static func validationFailure(for raw: String) -> StepValidationFailure? {
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
        return nil
    }

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
