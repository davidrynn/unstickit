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

                    Text("Keep it short. This is only to surface the real friction, not solve the whole thing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button(action: finish) {
                    Text("Start this step")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                VStack(spacing: 16) {
                    Button(action: handleStillStuck) {
                        Label("I'm still stuck", systemImage: "bubble.left")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

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
                    }

                    Divider()

                    Button {
                        model.saveForLater()
                    } label: {
                        Label("Save for later", systemImage: "bookmark")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        draft = ""
                        model.comeBackTomorrow()
                    } label: {
                        Label("Come back tomorrow", systemImage: "moon.zzz")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    if let confirmationMessage = model.confirmationMessage {
                        Text(confirmationMessage)
                            .font(.footnote)
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
        // on-screen — the shared overlay stayed up through the push transition —
        // then play the arrival flourish once the push has settled.
        .onAppear {
            nav.loadingMessage = nil
            revealStep()
        }
        // Dismissing the confirmation (Done or swipe-down) returns to a fresh
        // Unstick tab; the deferred step is already stored.
        .sheet(isPresented: $model.deferConfirmationShown, onDismiss: finish) {
            DeferConfirmationView(model: model)
                .presentationDetents([.medium])
        }
    }

    private func handleStillStuck() {
        // First tap reveals the smaller step inline; a later tap restarts from the dump.
        if !model.registerStillStuck() {
            nav.retry(with: model.brainDump)
        }
    }

    // Let the navigation push settle, then trigger the success haptic + checkmark
    // so the arrival reads as a deliberate flourish rather than fighting the push.
    private func revealStep() {
        guard !didReveal else { return }
        Task {
            try? await Task.sleep(for: .seconds(0.2))
            didReveal = true
        }
    }

    private func finish() {
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
