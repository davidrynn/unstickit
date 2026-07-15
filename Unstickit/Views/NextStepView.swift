import SwiftUI

struct NextStepView: View {
    @Environment(AppNavigation.self) private var nav

    @StateObject private var model: NextStepModel
    @AppStorage("draft_brain_dump") private var draft: String = ""

    // Drives the success haptic + checkmark flourish when this screen reveals the
    // resolved next step — the payoff moment of arriving at a clear step.
    @State private var didReveal = false

    init(
        result: NextStepResult,
        brainDump: String,
        store: RecommendedStepStore
    ) {
        self._model = StateObject(
            wrappedValue: NextStepModel(result: result, brainDump: brainDump, store: store)
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

                Button(action: finish) {
                    Text("Got it")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                VStack(spacing: 16) {
                    // "I'm still stuck" reveals a smaller step. Reveal-only now — a
                    // second tap no longer silently restarts the flow.
                    if model.fallbackRevealed {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If that still feels hard")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Text(model.fallbackStep)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        Button {
                            model.revealSmallerStep()
                        } label: {
                            Label("I'm still stuck", systemImage: "bubble.left")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
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
            }
            .padding(24)
        }
        .navigationTitle("Here's your next step")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.3), value: model.fallbackRevealed)
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

    /// "Got it" — the loop is completed; retain it and return to a fresh brain dump.
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
