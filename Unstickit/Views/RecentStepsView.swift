import SwiftUI

struct RecentStepsView: View {
    @Binding var path: NavigationPath

    @EnvironmentObject private var stepStore: RecommendedStepStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if stepStore.activeSteps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No recent steps")
                        .font(.headline)
                    Text("Steps you keep for later will show up here for a week.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 12)
            } else {
                ForEach(stepStore.activeSteps) { step in
                    NavigationLink {
                        RecentStepDetailView(step: step, path: $path)
                    } label: {
                        RecentStepRow(step: step)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .tint(.accentColor)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            stepStore.dismiss(step)
                        } label: {
                            Label("Let go", systemImage: "trash")
                        }

                        if step.isSaved {
                            Button {
                                stepStore.unsave(step)
                            } label: {
                                Label("Unsave", systemImage: "bookmark.slash")
                            }
                            .tint(.gray)
                        } else {
                            Button {
                                stepStore.save(step)
                            } label: {
                                Label("Save", systemImage: "bookmark")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recent steps")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                stepStore.purgeExpired()
            }
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

    @State private var addedContext = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var trimmedContext: String {
        addedContext.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
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

            if isLoading {
                FullScreenPauseLoaderOverlay(message: "Working on your reflection...",
                                            dotCount: 180)
                    .transition(.opacity)
            }
        }
        .navigationTitle("Recent step")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.14), value: isLoading)
    }

    private func submit() {
        guard !trimmedContext.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        let context = nextStepContext(additionalContext: trimmedContext)

        Task {
            do {
                let result = try await AIService.shared.extract(from: context)
                await MainActor.run {
                    isLoading = false
                    if result.isActionable {
                        path.append(AppDestination.reflection(result, brainDump: context))
                    } else {
                        errorMessage = result.clarificationPrompt ?? "Add a little more context before continuing."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
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
