import SwiftUI
import AnimationLoadersKit

struct BrainDumpView: View {
    @Binding var path: NavigationPath
    @Binding var retryText: String

    @EnvironmentObject private var stepStore: RecommendedStepStore
    @AppStorage("draft_brain_dump") private var draft: String = ""
    @State private var isLoading = false
    @State private var clarificationPrompt: String? = nil
    @State private var errorMessage: String? = nil
    @State private var showClearConfirmation = false

    private let loadingFadeDuration = 0.14
    private let loadingFadeDelayNanoseconds: UInt64 = 140_000_000

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 12) {
                        SandTextView(text: "UnStickIt",
                                     seed: 23,
                                     dotCount: 240,
                                     dotColor: .primary,
                                     backgroundColor: .clear)
                            .frame(height: 92)
                            .frame(maxWidth: .infinity)

                        if stepStore.hasActiveSteps {
                            NavigationLink {
                                RecentStepsView(path: $path)
                            } label: {
                                RecentStepsLink(
                                    count: stepStore.activeSteps.count
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }

                        Text("What are you stuck on?")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    TextEditor(text: $draft)
                        .frame(minHeight: 180)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(isLoading)

                    if let prompt = clarificationPrompt {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.tint)
                            Text(prompt)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    Button(action: submit) {
                        Text(isLoading ? "Thinking..." : "Next")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(trimmedDraft.isEmpty ? Color.gray : Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(trimmedDraft.isEmpty || isLoading)
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
        .animation(.easeInOut(duration: loadingFadeDuration), value: isLoading)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !trimmedDraft.isEmpty && !isLoading {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .confirmationDialog("Clear your brain dump?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear", role: .destructive) {
                draft = ""
                clarificationPrompt = nil
                errorMessage = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase everything you've written.")
        }
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                stepStore.purgeExpired()
            }
            // Apply retry text from "I'm still stuck" (second tap)
            if !retryText.isEmpty {
                draft = retryText
                retryText = ""
            }
            clarificationPrompt = nil
            errorMessage = nil
        }
    }

    private func submit() {
        guard !trimmedDraft.isEmpty else { return }
        let trimmed = trimmedDraft

        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        if wordCount < 4 {
            clarificationPrompt = "Tell me a bit more — what are you working on, and what's making it hard to move forward?"
            return
        }

        withAnimation(.easeInOut(duration: loadingFadeDuration)) {
            isLoading = true
        }
        errorMessage = nil
        clarificationPrompt = nil

        Task {
            do {
                let result = try await AIService.shared.extract(from: trimmed)
                await MainActor.run {
                    finishLoading {
                        if result.isActionable {
                            path.append(AppDestination.reflection(result, brainDump: trimmed))
                        } else {
                            clarificationPrompt = result.clarificationPrompt
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    finishLoading {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    @MainActor
    private func finishLoading(_ action: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: loadingFadeDuration)) {
            isLoading = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: loadingFadeDelayNanoseconds)
            action()
        }
    }
}

private struct RecentStepsLink: View {
    let count: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tray.full")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Recent steps")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }

                Text(count == 1 ? "1 step saved for later" : "\(count) steps saved for later")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
