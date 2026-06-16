import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var retryBrainDump: String = ""
    @StateObject private var stepStore = RecommendedStepStore()

    var body: some View {
        if AIService.shared.isAvailable() {
            NavigationStack(path: $path) {
                BrainDumpView(path: $path, retryText: $retryBrainDump)
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case .reflection(let extraction, let brainDump):
                            ReflectionView(extraction: extraction, brainDump: brainDump, path: $path)
                        case .clarification(let extraction, let clarification, let brainDump):
                            ClarificationView(
                                extraction: extraction,
                                clarification: clarification,
                                brainDump: brainDump,
                                path: $path
                            )
                        case .nextStep(let result, let brainDump):
                            NextStepView(
                                result: result,
                                brainDump: brainDump,
                                path: $path,
                                onRetry: { retry in
                                    retryBrainDump = retry
                                    path = NavigationPath()
                                }
                            )
                        }
                    }
            }
            .environmentObject(stepStore)
        } else {
            AIRequiredView()
        }
    }
}
