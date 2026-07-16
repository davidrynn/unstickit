import SwiftUI

struct NextStepView: View {
    @Environment(AppNavigation.self) private var nav

    @StateObject private var model: NextStepModel
    @AppStorage("draft_brain_dump") private var draft: String = ""

    // Drives the success haptic + checkmark flourish when this screen reveals the
    // resolved next step — the payoff moment of arriving at a clear step.
    @State private var didReveal = false
    @FocusState private var feedbackFocused: Bool

    private let brainDump: String

    private var isLoading: Bool { nav.loadingMessage != nil }

    init(
        result: NextStepResult,
        brainDump: String,
        context: NextStepContext,
        store: RecommendedStepStore
    ) {
        self.brainDump = brainDump
        self._model = StateObject(
            wrappedValue: NextStepModel(
                result: result,
                brainDump: brainDump,
                context: context,
                store: store
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                            .scaleEffect(didReveal ? 1 : 0.5)
                            .opacity(didReveal ? 1 : 0)

                        Text("Your next step")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }

                    Text(model.nextStep)
                        .font(.title)
                        .fontWeight(.semibold)
                }

                // "Did this help?" (did_this_help_spec.md): an honest yes/no beats a
                // one-way "Got it". "Not quite" is deliberately neutral, not red —
                // red stays reserved for the destructive escape hatch below.
                VStack(spacing: 12) {
                    Text("Did this help?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 12) {
                        Button(action: finish) {
                            Text("Yes")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button {
                            withAnimation { model.feedbackExpanded = true }
                            feedbackFocused = true
                        } label: {
                            Text("Not quite")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if model.feedbackExpanded {
                    feedbackSection
                }

                // Explicit escape hatch: discard this (silently-persisted) session
                // and return to a blank brain dump.
                Button(role: .destructive, action: startOver) {
                    Label("Delete & start over", systemImage: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.18 : 1)
        .navigationTitle("Here's your next step")
        .navigationBarTitleDisplayMode(.inline)
        // Same 0.35s as the shared loader overlay so dim and loader fade as one.
        .animation(.easeInOut(duration: 0.35), value: isLoading)
        .animation(.easeInOut(duration: 0.3), value: model.feedbackExpanded)
        // A fresh step arriving from "Try again" gets the same success haptic as the
        // original reveal.
        .sensoryFeedback(.success, trigger: model.regenerationCount)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: didReveal)
        .sensoryFeedback(.success, trigger: didReveal)
        // Clear the "Generating your next step..." loader now that this screen is
        // on-screen — the shared overlay stayed up through the push transition and
        // holds until the push settles — then play the arrival flourish.
        .onAppear {
            nav.dismissLoaderAfterPushSettles()
            model.recordSession()   // silently persist this session as an open loop
            revealStep()
        }
        // Dismissing the confirmation (Done or swipe-down) returns to a fresh
        // Unstick tab; the deferred step is already stored, so discard the open-loop
        // record (don't complete it) to avoid a spurious completed duplicate.
        .sheet(isPresented: $model.deferConfirmationShown, onDismiss: dismissDeferred) {
            DeferConfirmationView(model: model)
                .presentationDetents([.medium])
        }
    }

    /// "Not quite" expanded: an optional correction and one more try — or, once the
    /// attempts are used up, a nudge back to the dump (new words beat another roll).
    @ViewBuilder
    private var feedbackSection: some View {
        if model.canTryAgain {
            VStack(alignment: .leading, spacing: 12) {
                TextField(
                    "What's off? Correct me or add a detail — optional",
                    text: $model.feedbackText,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .focused($feedbackFocused)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: tryAgain) {
                    Text("Try again")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            VStack(spacing: 8) {
                Text("Two fresh takes didn't land — editing what you wrote usually helps more than another try.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Edit what I wrote", action: editWhatIWrote)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
            }
            .transition(.opacity)
        }
    }

    /// Regenerate behind the shared loader (same dim + curtain pattern as the
    /// reflection screen's reroll). The model swaps the step in place on completion.
    private func tryAgain() {
        guard nav.loadingMessage == nil else { return }
        feedbackFocused = false
        nav.loadingMessage = "Rethinking your step..."
        Task {
            await model.tryAgain()
            nav.loadingMessage = nil
        }
    }

    /// Cap-reached nudge: back to the dump with the text preserved so it can be
    /// refined. This session's open loop is discarded — the reworked dump records
    /// its own when it produces a step.
    private func editWhatIWrote() {
        model.discardSession()
        nav.retry(with: brainDump)
    }

    // Trigger the success haptic + checkmark only once this screen is actually in
    // view: the shared loader holds ~0.45s after arrival (dismissLoaderAfterPushSettles)
    // and fades over 0.35s, so anything earlier would flourish behind the curtain.
    private func revealStep() {
        guard !didReveal else { return }
        Task {
            try? await Task.sleep(for: .seconds(0.95))
            didReveal = true
        }
    }

    /// "Yes" (Did this help?) — the loop is completed; retain it and return to a
    /// fresh brain dump.
    private func finish() {
        model.completeSession()
        resetToFresh()
    }

    /// "Delete & start over" — discard this session and return to a fresh brain dump.
    private func startOver() {
        model.discardSession()
        resetToFresh()
    }

    /// Come-back-tomorrow hand-off: the deferred record created by `comeBackTomorrow()`
    /// supersedes the open-loop record, so discard it (don't complete it) on dismiss —
    /// otherwise a deferred step would leave a spurious completed duplicate.
    private func dismissDeferred() {
        model.discardSession()
        resetToFresh()
    }

    private func resetToFresh() {
        draft = ""
        nav.startUnstickFresh()
    }
}

/// "We'll hold this for tomorrow." confirmation (come_back_tomorrow_spec.md §3),
/// with an optional, non-blocking reminder offer.
private struct DeferConfirmationView: View {
    @ObservedObject var model: NextStepModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .padding(.top, 12)

            VStack(spacing: 8) {
                Text("We'll hold this for tomorrow.")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("No need to solve it right now. When you come back, we'll start from this step.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if model.reminderScheduled {
                    Label("Reminder set", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task { await model.setReminder() }
                    } label: {
                        Text("Set reminder")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(24)
    }
}
