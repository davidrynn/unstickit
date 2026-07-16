import Foundation
import FoundationModels

// MARK: - Stage 1: Extraction

@Generable
struct ExtractionResult {
    /// If false, brain dump needs more context before proceeding.
    /// Detailed criteria live in the extraction prompt; keep @Guide strings terse — they are
    /// compiled into the guided-generation schema and cost context-window tokens on every call.
    @Guide(description: "Whether there's enough to analyze")
    var isActionable: Bool

    /// Shown inline on the brain dump screen when isActionable is false
    @Guide(description: "A friendly question for more context; only when not actionable")
    var clarificationPrompt: String?

    /// One sentence describing what the user is trying to achieve
    @Guide(description: "One sentence: the user's goal")
    var goalSummary: String

    /// 1–3 blockers identified from the brain dump
    @Guide(description: "1 to 3 blockers")
    var blockers: [Blocker]

    /// One sentence describing what is making this emotionally or practically hard
    @Guide(description: "One warm second-person sentence naming what makes this hard")
    var frictionSummary: String

    /// Second-person display line shown on the Reflection + Choice screen (S2)
    @Guide(description: "One second-person sentence, at most 28 words")
    var summary: String
}

@Generable
struct Blocker {
    /// Plain language description shown to the user
    @Guide(description: "The blocker in one plain sentence")
    var description: String

    /// Internal — revealed on demand via disclosure tap
    @Guide(description: "practical, informational, or emotional")
    var type: BlockerType
}

@Generable
enum BlockerType: String, Codable {
    /// Missing resources, tools, skills, or access
    case practical
    /// Unclear path, criteria, or decision needed
    case informational
    /// Fear, avoidance, overwhelm, or emotional friction
    case emotional

    var label: String {
        switch self {
        case .practical: return "Practical"
        case .informational: return "Informational"
        case .emotional: return "Emotional"
        }
    }
}

// MARK: - Stage 2: Clarification

/// The type of stuck situation — used to constrain Stage 3 generation.
@Generable
enum StuckMode: String, Codable {
    /// User has tried multiple approaches with no success — needs to isolate what's failing
    case reproduce
    /// User doesn't know where to begin or what the real problem is — needs to reduce scope
    case narrow
    /// User feels overwhelmed or scattered — needs to identify the one thing to focus on
    case clarify

    /// All modes — Stage 2 should surface exactly one option per mode (spec §6).
    static let allModes: [StuckMode] = [.reproduce, .narrow, .clarify]
}

@Generable
struct ClarificationOption {
    /// Short first-person phrase shown as a tappable button
    @Guide(description: "A short first-person phrase describing how the user feels stuck, specific to their situation (e.g. 'I keep trying fixes and nothing sticks')")
    var label: String

    /// Internal — determines what kind of activation step Stage 3 generates
    @Guide(description: "The stuckness mode this option represents")
    var mode: StuckMode
}

@Generable
struct ClarificationResult {
    /// Exactly 3 options — one per StuckMode — shown as tappable buttons. The `.count(3)`
    /// constraint enforces the count at the guided-generation schema level; it cannot enforce
    /// one-per-mode, so `AIService.clarify()` still dedups/rerolls on mode coverage.
    @Guide(description: "Exactly 3 options, one for each StuckMode (reproduce, narrow, clarify), each with a label specific to the user's situation", .count(3))
    var options: [ClarificationOption]
}

// MARK: - POC: blocker-derived options (known_issues.md #5)

extension ClarificationResult {
    /// POC alternative to the Stage 2 model call: the tappable options ARE the Stage 1
    /// blockers, recast to first person, so every option is grounded in something the user
    /// actually wrote — the generated options repeatedly came back as prompt echoes instead.
    /// Stage 3 guidance is selected via `BlockerType.impliedMode`. The generated-options path
    /// (`AIService.clarify`) remains reachable behind "Something else" and as the fallback
    /// when extraction returned no blockers.
    static func derived(from extraction: ExtractionResult) -> ClarificationResult {
        ClarificationResult(options: extraction.blockers.map {
            ClarificationOption(
                label: firstPersonLabel(from: $0.description),
                mode: $0.type.impliedMode
            )
        })
    }

    /// Stage 1 writes blockers in second person ("You don't know what to do next"); a
    /// tappable identify-with statement reads in first person ("I don't know what to do
    /// next"). Plain word-boundary pronoun swap — POC-grade, not a grammar engine; text
    /// with no second-person pronouns ("The name of the app is incorrect") passes through
    /// unchanged, which already reads fine as an option.
    static func firstPersonLabel(from secondPerson: String) -> String {
        // Normalize curly apostrophes so one pattern set matches model output either way.
        var result = secondPerson.replacingOccurrences(of: "\u{2019}", with: "'")
        // Longest-first so "you're"/"yourself" aren't clipped by the "you"/"your" swaps.
        let swaps: [(String, String)] = [
            ("you're", "I'm"),
            ("you are", "I am"),
            ("you've", "I've"),
            ("you'll", "I'll"),
            ("you'd", "I'd"),
            ("yourself", "myself"),
            ("yours", "mine"),
            ("your", "my"),
            ("you", "I")
        ]
        for (second, first) in swaps {
            result = result.replacingOccurrences(
                of: "\\b\(second)\\b",
                with: first,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        // A swap can leave a lowercase word at the start ("my app's name is wrong").
        if let firstChar = result.first, firstChar.isLowercase {
            result = result.prefix(1).uppercased() + result.dropFirst()
        }
        return result
    }
}

extension BlockerType {
    /// Which kind of Stage 3 guidance a blocker of this type calls for when the user taps it
    /// as their option (POC: blocker-as-options). A concrete obstacle or an unclear path both
    /// want the narrow guidance (first move on the most concrete piece); emotional friction
    /// wants clarify (first move on the most pressing thing). No blocker type implies
    /// `reproduce` — it stays reachable only via the generated "Something else" set.
    var impliedMode: StuckMode {
        switch self {
        case .practical, .informational: return .narrow
        case .emotional: return .clarify
        }
    }
}

// MARK: - Stage 3: Next Step Generation

/// The model-generated activation step. Guided to be the first real, concrete move on the
/// user's actual task; a deterministic template is used as a fallback if generation fails
/// or the output doesn't pass validation (see `AIService.generateNextStep`).
@Generable
struct ActivationStep {
    @Guide(description: "One simple, concrete first action on the user's actual task — the first real move, startable right now. One or two short sentences, at most 30 words total, starting with an action verb and naming a specific thing from their situation. Not advice, not a plan, not a numbered list, no therapy language.")
    var step: String
}

/// The next-step payload shown on S3. `nextStep` is model-generated when possible,
/// otherwise a safe template; `fallbackStep` is a deterministic template kept as the
/// worst-case replacement when a "Not quite" regeneration fails (did_this_help_spec.md —
/// it is no longer a user-facing reveal).
struct NextStepResult {
    var nextStep: String
    var fallbackStep: String
}

/// The Stage 3 inputs carried alongside a generated step so it can be regenerated when
/// the user answers "Not quite" on the next-step screen (did_this_help_spec.md) — the
/// same inputs `generateNextStep` used, minus the rejected output itself.
struct NextStepContext: Hashable {
    var summary: String
    var mode: StuckMode
    var optionLabel: String
}

/// Constrained "Not quite" retry (did_this_help_spec.md): after a rejection, the model no
/// longer writes the step — it only fills these two slots, and the step is assembled from
/// a deterministic frame. `task` is validated in code against the user's own words, so a
/// hallucinated task is a caught failure, not a shipped one.
@Generable
struct StepIngredients {
    @Guide(description: "The ONE task from the user's own words to start with — 2 to 8 words, as close to verbatim as possible")
    var task: String

    @Guide(description: "The smallest first action on that task — 2 to 8 words starting with a verb, doable in two minutes (e.g. 'write down the first exercise' or 'draft one sentence about who it is for')")
    var firstAction: String
}
