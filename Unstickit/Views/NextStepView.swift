import SwiftUI

struct NextStepView: View {
    let result: NextStepResult
    let brainDump: String
    @Binding var path: NavigationPath
    let onRetry: (String) -> Void

    @EnvironmentObject private var stepStore: RecommendedStepStore
    @AppStorage("draft_brain_dump") private var draft: String = ""
    @State private var fallbackRevealed = false
    @State private var stillStuckCount = 0
    @State private var confirmationMessage: String? = nil
    @State private var showTomorrowConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your next step")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(result.nextStep)
                        .font(.title3)
                        .fontWeight(.medium)
                }

                if fallbackRevealed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("If that still feels hard")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(result.fallbackStep)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Button("Save smaller step") {
                            stepStore.saveFallbackStep(text: result.fallbackStep, brainDump: brainDump)
                            confirmationMessage = "Saved."
                        }
                        .font(.subheadline)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Button(action: finish) {
                    Text("Start")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: handleStillStuck) {
                    Text("I'm still stuck")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                Button {
                    deferUntilTomorrow()
                } label: {
                    Text("Come back tomorrow")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                Button {
                    stepStore.saveStep(text: result.nextStep, fallbackText: result.fallbackStep, brainDump: brainDump)
                    confirmationMessage = "Saved."
                } label: {
                    Text("Save this step")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                if let confirmationMessage {
                    Text(confirmationMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
        .navigationTitle("Here's your step")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.3), value: fallbackRevealed)
        .alert("We'll hold this for tomorrow.", isPresented: $showTomorrowConfirmation) {
            Button("Done") {
                path = NavigationPath()
            }
        } message: {
            Text("No need to solve it right now. When you come back, we'll start from this step.")
        }
    }

    private func handleStillStuck() {
        stillStuckCount += 1
        if stillStuckCount == 1 {
            fallbackRevealed = true
        } else {
            // Second tap — pre-fill brain dump and restart
            onRetry(brainDump)
        }
    }

    private func finish() {
        draft = ""
        path = NavigationPath()
    }

    private func deferUntilTomorrow() {
        stepStore.deferUntilTomorrow(
            text: result.nextStep,
            fallbackText: result.fallbackStep,
            brainDump: brainDump
        )
        draft = ""
        showTomorrowConfirmation = true
    }
}
