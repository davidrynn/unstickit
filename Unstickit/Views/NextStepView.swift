import SwiftUI

struct NextStepView: View {
    @Environment(AppNavigation.self) private var nav

    @StateObject private var model: NextStepModel
    @AppStorage("draft_brain_dump") private var draft: String = ""

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
                    Text("Your next step")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

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
    }

    private func handleStillStuck() {
        // First tap reveals the smaller step inline; a later tap restarts from the dump.
        if !model.registerStillStuck() {
            nav.retry(with: model.brainDump)
        }
    }

    private func finish() {
        draft = ""
        nav.startUnstickFresh()
    }
}
