import SwiftUI

/// Root tab shell: the **Unstick** flow and the **Saved** steps tab.
struct RootTabView: View {
    @StateObject private var stepStore = RecommendedStepStore()
    @State private var nav = AppNavigation()

    var body: some View {
        @Bindable var nav = nav

        TabView(selection: $nav.selectedTab) {
            NavigationStack(path: $nav.unstickPath) {
                BrainDumpView(path: $nav.unstickPath)
                    .appDestinations(path: $nav.unstickPath, store: stepStore)
            }
            .tabItem {
                Label("Unstick", systemImage: "sparkles")
            }
            .tag(AppTab.unstick)

            NavigationStack(path: $nav.savedPath) {
                RecentStepsView(path: $nav.savedPath)
                    .appDestinations(path: $nav.savedPath, store: stepStore)
            }
            .tabItem {
                Label("Saved", systemImage: "bookmark")
            }
            .badge(stepStore.savedSteps.count)
            .tag(AppTab.saved)
        }
        .environment(nav)
        .environmentObject(stepStore)
    }
}

private extension View {
    /// Shared `navigationDestination` handling so both tab stacks resolve `AppDestination`.
    func appDestinations(
        path: Binding<NavigationPath>,
        store: RecommendedStepStore
    ) -> some View {
        navigationDestination(for: AppDestination.self) { destination in
            switch destination {
            case .reflection(let extraction, let brainDump):
                ReflectionView(extraction: extraction, brainDump: brainDump, path: path)
            case .clarification(let extraction, let clarification, let brainDump):
                ClarificationView(
                    extraction: extraction,
                    clarification: clarification,
                    brainDump: brainDump,
                    path: path
                )
            case .reflectionChoice(let extraction, let clarification, let brainDump):
                ReflectionChoiceView(
                    extraction: extraction,
                    clarification: clarification,
                    brainDump: brainDump,
                    path: path
                )
            case .nextStep(let result, let brainDump):
                NextStepView(
                    result: result,
                    brainDump: brainDump,
                    store: store
                )
            }
        }
    }
}
