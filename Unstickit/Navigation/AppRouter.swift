import SwiftUI

enum AppDestination: Hashable {
    case reflection(ExtractionResult)
    case clarification(extraction: ExtractionResult, clarification: ClarificationResult)
    case nextStep(NextStepResult, brainDump: String)
}

extension ExtractionResult: Hashable {
    static func == (lhs: ExtractionResult, rhs: ExtractionResult) -> Bool {
        lhs.goalSummary == rhs.goalSummary
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(goalSummary)
    }
}

extension ClarificationResult: Hashable {
    static func == (lhs: ClarificationResult, rhs: ClarificationResult) -> Bool {
        lhs.options.first?.label == rhs.options.first?.label
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(options.first?.label)
    }
}

extension NextStepResult: Hashable {
    static func == (lhs: NextStepResult, rhs: NextStepResult) -> Bool {
        lhs.nextStep == rhs.nextStep
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(nextStep)
    }
}
