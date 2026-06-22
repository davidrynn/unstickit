import SwiftUI

struct RecentStepsView: View {
    @Binding var path: NavigationPath

    @EnvironmentObject private var stepStore: RecommendedStepStore
    @Environment(AppNavigation.self) private var nav

    @State private var pendingAction: PendingAction?

    /// A destructive action that requires confirmation before it runs.
    private enum PendingAction: Identifiable {
        /// Delete a saved step (spec §4 — "Let go" requires confirmation for saved steps).
        case delete(RecommendedStep)
        /// Unsave a step whose 7-day window has already passed, so it deletes immediately.
        case unsave(RecommendedStep)

        var id: UUID {
            switch self {
            case .delete(let step), .unsave(let step): return step.id
            }
        }
    }

    var body: some View {
        List {
            if stepStore.savedSteps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No saved steps")
                        .font(.headline)
                    Text("Steps you keep for later will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 12)
            } else {
                ForEach(stepStore.savedSteps) { step in
                    NavigationLink {
                        RecentStepDetailView(step: step, path: $path)
                    } label: {
                        RecentStepRow(step: step)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            nav.startUnstickFresh()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .tint(.accentColor)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            requestLetGo(step)
                        } label: {
                            Label("Let go", systemImage: "trash")
                        }

                        Button {
                            requestUnsave(step)
                        } label: {
                            Label("Unsave", systemImage: "bookmark.slash")
                        }
                        .tint(.gray)
                    }
                    // Accessible equivalents for the swipe actions (spec §4).
                    .contextMenu {
                        Button {
                            nav.startUnstickFresh()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        Button {
                            requestUnsave(step)
                        } label: {
                            Label("Unsave", systemImage: "bookmark.slash")
                        }
                        Button(role: .destructive) {
                            requestLetGo(step)
                        } label: {
                            Label("Let go", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete saved step?",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingAction
        ) { action in
            Button("Delete", role: .destructive) { perform(action) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This removes it from your saved steps.")
        }
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                stepStore.purgeExpired()
            }
        }
    }

    /// The Saved tab shows saved steps only, so every "Let go" deletes a saved
    /// step and must be confirmed (spec §4).
    private func requestLetGo(_ step: RecommendedStep) {
        pendingAction = .delete(step)
    }

    /// Unsaving sets `expiresAt` to 7 days after `createdAt`. If that moment has
    /// already passed the step is deleted immediately, so confirm first (spec §4).
    private func requestUnsave(_ step: RecommendedStep) {
        let expiry = Calendar.current.date(byAdding: .day, value: 7, to: step.createdAt)
        if let expiry, expiry <= Date() {
            pendingAction = .unsave(step)
        } else {
            stepStore.unsave(step)
        }
    }

    private func perform(_ action: PendingAction) {
        switch action {
        case .delete(let step): stepStore.dismiss(step)
        case .unsave(let step): stepStore.unsave(step)
        }
    }
}

private struct RecentStepRow: View {
    let step: RecommendedStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)

            HStack(spacing: 8) {
                if step.isSaved {
                    Label("Saved", systemImage: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(dateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(step.createdAt) {
            return "Today"
        }
        if calendar.isDateInYesterday(step.createdAt) {
            return "Yesterday"
        }
        return step.createdAt.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct RecentStepDetailView: View {
    let step: RecommendedStep
    @Binding var path: NavigationPath

    @Environment(AppNavigation.self) private var nav
    @State private var addedContext = ""
    @State private var errorMessage: String? = nil

    /// Shared loader (see `AppNavigation.loadingMessage`) so it persists across the
    /// push to the combined screen, cleared by `ReflectionChoiceView.onAppear`.
    private var isLoading: Bool { nav.loadingMessage != nil }

    private var trimmedContext: String {
        addedContext.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Issue")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(step.issueSummary)
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last step")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(step.text)
                            .font(.title3)
                            .fontWeight(.medium)
                    }

                    if let fallbackText = step.fallbackText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Smaller step")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Text(fallbackText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ready for the next step?")
                            .font(.title3)
                            .fontWeight(.medium)

                        TextEditor(text: $addedContext)
                            .frame(minHeight: 150)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(isLoading)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    Button(action: submit) {
                        Text(isLoading ? "Thinking..." : "Next")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(trimmedContext.isEmpty ? Color.gray : Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(trimmedContext.isEmpty || isLoading)
                }
                .padding(24)
            }
        .disabled(isLoading)
        .opacity(isLoading ? 0.18 : 1)
        .navigationTitle("Recent step")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.14), value: isLoading)
    }

    private func submit() {
        guard !trimmedContext.isEmpty else { return }
        // Shared loader, held up across the push; cleared by ReflectionChoiceView.onAppear.
        nav.loadingMessage = "Working on your reflection..."
        errorMessage = nil

        let context = nextStepContext(additionalContext: trimmedContext)

        Task {
            do {
                // Mirror BrainDumpView: extraction + best-effort clarification behind one
                // loader, then route through the combined Reflection + Choice screen.
                let extraction = try await AIService.shared.extract(from: context)
                guard extraction.isActionable else {
                    nav.loadingMessage = nil
                    errorMessage = extraction.clarificationPrompt ?? "Add a little more context before continuing."
                    return
                }
                // If clarification fails, the combined screen still shows the summary and
                // offers a retry (T7) — don't dead-end here.
                let clarification = try? await AIService.shared.clarify(extraction: extraction)
                // Non-animated push so the loader hides the navigation entirely
                // (cleared by ReflectionChoiceView.onAppear).
                nav.pushBehindLoader(
                    .reflectionChoice(
                        extraction: extraction,
                        clarification: clarification,
                        brainDump: context
                    ),
                    path: $path
                )
            } catch {
                nav.loadingMessage = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func nextStepContext(additionalContext: String) -> String {
        var parts: [String] = []

        if let originalBrainDump = step.originalBrainDump?.trimmingCharacters(in: .whitespacesAndNewlines),
           !originalBrainDump.isEmpty {
            parts.append("Original issue: \(originalBrainDump)")
        }

        parts.append("Previous step: \(step.text)")

        if let fallbackText = step.fallbackText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fallbackText.isEmpty {
            parts.append("Smaller step option: \(fallbackText)")
        }

        parts.append("What happened or changed: \(additionalContext)")
        parts.append("Now help me find the next small step.")

        return parts.joined(separator: "\n\n")
    }
}
