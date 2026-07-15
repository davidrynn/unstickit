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
/// otherwise a safe template; `fallbackStep` (the "I'm still stuck" smaller step) is
/// always a deterministic template.
struct NextStepResult {
    var nextStep: String
    var fallbackStep: String
}
