import SwiftUI

/// Root tab shell: the **Start** flow and the **Recent** steps tab.
struct RootTabView: View {
    @StateObject private var stepStore = RecommendedStepStore()
    @StateObject private var sessionLog = SessionLogStore()
    @State private var nav = AppNavigation()

    var body: some View {
        @Bindable var nav = nav

        TabView(selection: $nav.selectedTab) {
            NavigationStack(path: $nav.unstickPath) {
                BrainDumpView(path: $nav.unstickPath)
                    .appDestinations(path: $nav.unstickPath, store: stepStore, sessionLog: sessionLog, nav: nav)
            }
            .tabItem {
                Label("Start", systemImage: "sparkles")
            }
            .tag(AppTab.unstick)

            NavigationStack(path: $nav.savedPath) {
                RecentStepsView(path: $nav.savedPath)
                    .appDestinations(path: $nav.savedPath, store: stepStore, sessionLog: sessionLog, nav: nav)
            }
            .tabItem {
                Label("Recent", systemImage: "clock")
            }
            .badge(stepStore.unseenSavedCount)
            .tag(AppTab.saved)
        }
        // The badge is "new since you last looked": opening the Saved tab clears it.
        .onChange(of: nav.selectedTab) { _, tab in
            if tab == .saved { stepStore.markSavedSeen() }
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
        // Unhurried fade: the loader is a deliberate pause (see
        // FullScreenPauseLoaderOverlay), so it eases in/out slowly enough that the
        // screens beneath never appear to snap. Matches the 0.35s dim on the screens
        // that drive `loadingMessage`.
        .animation(.easeInOut(duration: 0.35), value: nav.loadingMessage)
        .environment(nav)
        .environmentObject(stepStore)
    }
}

private extension View {
    /// Shared `navigationDestination` handling so both tab stacks resolve `AppDestination`.
    func appDestinations(
        path: Binding<NavigationPath>,
        store: RecommendedStepStore,
        sessionLog: SessionLogStore,
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
                    nav: nav,
                    sessionLog: sessionLog
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
