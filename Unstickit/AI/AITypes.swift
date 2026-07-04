import Foundation
import FoundationModels

// MARK: - Stage 1: Extraction

@Generable
struct ExtractionResult {
    /// If false, brain dump needs more context before proceeding
    @Guide(description: "Whether the input describes a real stuck situation with enough context to analyze")
    var isActionable: Bool

    /// Shown inline on the brain dump screen when isActionable is false
    @Guide(description: "A single friendly question asking for more context, only set when isActionable is false")
    var clarificationPrompt: String?

    /// One sentence describing what the user is trying to achieve
    @Guide(description: "A single sentence summarizing the user's goal")
    var goalSummary: String

    /// 1–3 blockers identified from the brain dump
    @Guide(description: "Between 1 and 3 blockers preventing the user from moving forward")
    var blockers: [Blocker]

    /// One sentence describing what is making this emotionally or practically hard
    @Guide(description: "A single warm, empathetic sentence validating why this situation is genuinely hard — use second person, be specific, avoid therapy language or generic platitudes")
    var frictionSummary: String

    /// Second-person display line shown on the Reflection + Choice screen (S2)
    @Guide(description: "A single second-person sentence of at most 28 words that names what the user wants to accomplish and the friction getting in the way. One short paragraph. No diagnosis, no therapy language, no generic encouragement. Example: 'You want to finish your app, but AI/SwiftUI bugs keep making the next step feel unclear.'")
    var summary: String
}

@Generable
struct Blocker {
    /// Plain language description shown to the user
    @Guide(description: "A plain language description of the blocker, one sentence")
    var description: String

    /// Internal — revealed on demand via disclosure tap
    @Guide(description: "The category of this blocker")
    var type: BlockerType
}

@Generable
enum BlockerType: String {
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
enum StuckMode: String {
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
    /// Exactly 3 options — one per StuckMode — shown as tappable buttons
    @Guide(description: "Exactly 3 options, one for each StuckMode (reproduce, narrow, clarify), each with a label specific to the user's situation")
    var options: [ClarificationOption]
}

// MARK: - Stage 3: Next Step Generation

/// The model-generated activation step. Guided to be tiny and intentionally
/// incomplete; a deterministic template is used as a fallback if generation fails
/// or the output doesn't pass validation (see `AIService.generateNextStep`).
@Generable
struct ActivationStep {
    @Guide(description: "One very small first action the user can do in about two minutes right now, written as a single imperative sentence of at most 25 words. It must fit their specific situation and use their own domain — not generic advice. It should surface the real friction or a starting point, NOT solve the whole problem; it is intentionally incomplete. No therapy language, no encouragement, no multi-step plans, no numbered lists.")
    var step: String
}

/// The next-step payload shown on S3. `nextStep` is model-generated when possible,
/// otherwise a safe template; `fallbackStep` (the "I'm still stuck" smaller step) is
/// always a deterministic template.
struct NextStepResult {
    var nextStep: String
    var fallbackStep: String
}
