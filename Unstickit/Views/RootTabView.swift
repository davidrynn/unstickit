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
                    .appDestinations(path: $nav.unstickPath, store: stepStore, nav: nav)
            }
            .tabItem {
                Label("Unstick", systemImage: "sparkles")
            }
            .tag(AppTab.unstick)

            NavigationStack(path: $nav.savedPath) {
                RecentStepsView(path: $nav.savedPath)
                    .appDestinations(path: $nav.savedPath, store: stepStore, nav: nav)
            }
            .tabItem {
                Label("Saved", systemImage: "bookmark")
            }
            .badge(stepStore.savedSteps.count)
            .tag(AppTab.saved)
        }
        // One full-screen loader for the whole shell, driven by shared state. Sitting
        // above the TabView keeps it visible across navigation pushes; each
        // destination clears `nav.loadingMessage` in its `.onAppear` (§ view-model
        // ownership), so it never disappears mid-transition.
        .overlay {
            if let message = nav.loadingMessage {
                FullScreenPauseLoaderOverlay(message: message, dotCount: 180)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.14), value: nav.loadingMessage)
        .environment(nav)
        .environmentObject(stepStore)
    }
}

private extension View {
    /// Shared `navigationDestination` handling so both tab stacks resolve `AppDestination`.
    func appDestinations(
        path: Binding<NavigationPath>,
        store: RecommendedStepStore,
        nav: AppNavigation
    ) -> some View {
        navigationDestination(for: AppDestination.self) { destination in
            switch destination {
            case .reflectionChoice(let extraction, let clarification, let brainDump):
                ReflectionChoiceView(
                    extraction: extraction,
                    clarification: clarification,
                    brainDump: brainDump,
                    path: path,
                    nav: nav
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
