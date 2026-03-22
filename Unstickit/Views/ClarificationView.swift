import SwiftUI

struct ClarificationView: View {
    let extraction: ExtractionResult
    let clarification: ClarificationResult
    @Binding var path: NavigationPath

    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Which feels most true right now?")
                    .font(.title3)
                    .fontWeight(.medium)

                VStack(spacing: 12) {
                    ForEach(clarification.options.indices, id: \.self) { i in
                        OptionButton(
                            label: clarification.options[i].label,
                            isLoading: isLoading
                        ) {
                            select(clarification.options[i].mode)
                        }
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
        .navigationTitle("One quick check")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ mode: StuckMode) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await AIService.shared.generateNextStep(
                    extraction: extraction,
                    selectedMode: mode
                )
                await MainActor.run {
                    isLoading = false
                    path.append(AppDestination.nextStep(result, brainDump: ""))
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct OptionButton: View {
    let label: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                Spacer()
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }
}
