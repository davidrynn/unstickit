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

/// On-device model availability, mapped to a UI-facing enum so views don't import FoundationModels.
enum AIAvailability: Equatable {
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
        - Begin with a concrete action verb: Write, Open, Pick, Find, Put, Set a timer, \
        Look at. The step must be a physical, observable action — NOT a feeling, a mindset, or \
        reassurance.
        - ONE action on ONE thing — a single imperative sentence, at most 25 words. NOT two \
        actions joined by "and", NOT several items, NOT "three things" and NOT "for each". Just \
        one small move.
        - It must be finishable in under two minutes: read one thing, write a single sentence, \
        or make one small choice. NEVER ask them to write a summary, a draft, an outline, a \
        list of items, or more than one sentence — that is too big.
        - Concrete and specific to THEIR situation — use their domain, not generic advice.
        - Intentionally incomplete: surface the real friction or a starting point; do not \
        try to solve the whole thing.
        - No therapy language, no pep talk, no "remind yourself", no numbered steps.

        The right shape (these describe the FORM to follow — they are NOT sentences to copy):
        - it names the SINGLE most relevant thing from THEIR situation and stops
        - or it sets a two-minute timer and does only the smallest first slice of THEIR situation
        - or it opens or looks at one thing and engages with just the first part of it
        Write a brand-new sentence in THEIR words about THEIR situation. Do not reuse wording from \
        these descriptions or from any example anywhere.

        Never produce:
        - reassurance or a feeling ("take a breath", "remind yourself…") — that is not an action
        - anything plan-sized or multi-step ("make a plan to get back on track")
        - several items or "for each" ("list three ideas and write why each appeals") — one thing only
        """

        let step: String?
        do {
            let response = try await session.respond(to: prompt, generating: ActivationStep.self)
            let raw = response.content.step
            step = Self.validatedStep(raw)
            #if DEBUG
            if step == nil {
                print("⚠️ STAGE 3 rejected model output (copied example / too long / " +
                    "multi-sentence / empty), using fallback. Raw: \(raw)")
            }
            #endif
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
        // The prompt asks for ≤25 words; allow some slack before rejecting as a plan/ramble
        // so it falls back to the template. 35 (rather than a tight 30) keeps good, on-topic
        // steps that spend a few words on a parenthetical (e.g. listing their own platforms)
        // instead of discarding them on length alone. (Tone — e.g. pep talk — can't be checked
        // here; the prompt's few-shot handles that.)
        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        guard wordCount <= 35 else { return nil }
        // One action, one sentence. `reproduce` mode especially tends to return two
        // sentences ("List what you tried. Then pick one.") that slip under the word cap;
        // reject anything past a single sentence so it falls back to the template. Uses the
        // locale sentence tokenizer, which keeps abbreviations (e.g. "vs.") intact.
        guard sentenceCount(trimmed) <= 1 else { return nil }
        // Anti-copy guard: small on-device models sometimes echo an illustrative phrase from
        // the prompt verbatim instead of writing something for the user's actual situation
        // (e.g. a debugging example surfacing for a coffee-newsletter input). Reject any output
        // that matches a known example/placeholder so the caller falls back to a template.
        let normalized = normalizedForComparison(trimmed)
        for phrase in forbiddenStepPhrases {
            let normalizedPhrase = normalizedForComparison(phrase)
            guard !normalizedPhrase.isEmpty else { continue }
            if normalized == normalizedPhrase
                || normalized.contains(normalizedPhrase)
                || normalizedPhrase.contains(normalized) {
                return nil
            }
        }
        return trimmed
    }

    /// Illustrative/placeholder phrases that must never reach the user. These include the
    /// example shapes referenced by the Stage-3 prompt and canned outputs the model tends to
    /// regurgitate. Matching is done on a normalized form (see `normalizedForComparison`), so
    /// punctuation/casing differences in the model's echo are still caught.
    private static let forbiddenStepPhrases: [String] = [
        "Write down the three job titles you'd actually be glad to get, then stop.",
        "Set a timer for two minutes and put away only the things on the garage floor.",
        "Open the file where the error happens and read just the first function.",
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
