import SwiftUI

struct NextStepView: View {
    let result: NextStepResult
    let brainDump: String
    @Binding var path: NavigationPath
    let onRetry: (String) -> Void

    @AppStorage("draft_brain_dump") private var draft: String = ""
    @State private var fallbackRevealed = false
    @State private var stillStuckCount = 0

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
            }
            .padding(24)
        }
        .navigationTitle("Here's your step")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.3), value: fallbackRevealed)
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
}
