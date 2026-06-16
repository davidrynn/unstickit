import SwiftUI
import AnimationLoadersKit

struct ClarificationView: View {
    let extraction: ExtractionResult
    let clarification: ClarificationResult
    let brainDump: String
    @Binding var path: NavigationPath

    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private let loadingFadeDuration = 0.14
    private let loadingFadeDelayNanoseconds: UInt64 = 140_000_000

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Which feels most true right now?")
                        .font(.title3)
                        .fontWeight(.medium)

                    VStack(spacing: 12) {
                        ForEach(clarification.options.indices, id: \.self) { i in
                            OptionButton(
                                label: clarification.options[i].label
                            ) {
                                select(clarification.options[i].mode)
                            }
                            .disabled(isLoading)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                        Button("Try again") { errorMessage = nil }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(24)
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.18 : 1)

            if isLoading {
                FullScreenPauseLoaderOverlay(message: "Generating your next step...",
                                             dotCount: 160)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: loadingFadeDuration), value: isLoading)
        .navigationTitle("One quick check")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ mode: StuckMode) {
        withAnimation(.easeInOut(duration: loadingFadeDuration)) {
            isLoading = true
        }
        errorMessage = nil

        Task {
            do {
                let result = try await AIService.shared.generateNextStep(
                    extraction: extraction,
                    selectedMode: mode
                )
                await MainActor.run {
                    finishLoading {
                        path.append(AppDestination.nextStep(result, brainDump: brainDump))
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

private struct OptionButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
