import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var retryBrainDump: String = ""

    var body: some View {
        if AIService.shared.isAvailable() {
            NavigationStack(path: $path) {
                BrainDumpView(path: $path, retryText: $retryBrainDump)
                    .navigationDestination(for: AppDestination.self) { destination in
                        switch destination {
                        case .reflection(let extraction):
                            ReflectionView(extraction: extraction, path: $path)
                        case .clarification(let extraction, let clarification):
                            ClarificationView(
                                extraction: extraction,
                                clarification: clarification,
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
        } else {
            AIRequiredView()
        }
    }
}
