import SwiftUI

struct ReflectionView: View {
    let extraction: ExtractionResult
    let brainDump: String
    @Binding var path: NavigationPath

    @State private var clarification: ClarificationResult? = nil
    @State private var isConfirming = false
    @State private var isLoadingClarification = false
    @State private var errorMessage: String? = nil

    private let loadingFadeDuration = 0.14
    private let loadingFadeDelayNanoseconds: UInt64 = 140_000_000

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                ReflectionSection(title: "Your goal") {
                    Text(extraction.goalSummary)
                        .font(.body)
                }

                ReflectionSection(title: "What might be blocking you") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(extraction.blockers.indices, id: \.self) { i in
                            BlockerRow(blocker: extraction.blockers[i])
                        }
                    }
                }

                ReflectionSection(title: "What might be making this hard") {
                    Text(extraction.frictionSummary)
                        .font(.body)
                }

                ReflectionSection(title: "Something I noticed") {
                    Text(extraction.whatINoticed)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Does this sound right?")
                        .font(.headline)

                    Button(action: confirmAndProceed) {
                        Text(isConfirming ? "Finding your options..." : "Yes, that's it")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isConfirming)

                    Button("Something's off — let me adjust") {
                        path = NavigationPath()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Button("Try again") { loadClarification() }
                        .buttonStyle(.bordered)
                }
                }
                .padding(24)
            }
            .disabled(isLoadingClarification)
            .opacity(isLoadingClarification ? 0.18 : 1)

            if isLoadingClarification {
                FullScreenPauseLoaderOverlay(message: "Preparing your options...",
                                             dotCount: 170)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: loadingFadeDuration), value: isLoadingClarification)
        .navigationTitle("Here's what I see")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadClarification() }
    }

    private func confirmAndProceed() {
        if let c = clarification {
            path.append(AppDestination.clarification(
                extraction: extraction,
                clarification: c,
                brainDump: brainDump
            ))
        } else {
            isConfirming = true
        }
    }

    private func loadClarification() {
        errorMessage = nil
        withAnimation(.easeInOut(duration: loadingFadeDuration)) {
            isLoadingClarification = true
        }
        Task {
            do {
                let result = try await AIService.shared.clarify(extraction: extraction)
                await MainActor.run {
                    finishLoadingClarification {
                        clarification = result
                        if isConfirming {
                            path.append(AppDestination.clarification(
                                extraction: extraction,
                                clarification: result,
                                brainDump: brainDump
                            ))
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    finishLoadingClarification {
                        isConfirming = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    @MainActor
    private func finishLoadingClarification(_ action: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: loadingFadeDuration)) {
            isLoadingClarification = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: loadingFadeDelayNanoseconds)
            action()
        }
    }
}

// MARK: - Subviews

private struct ReflectionSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }
}

private struct BlockerRow: View {
    let blocker: Blocker

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(blocker.description)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            BlockerTypePill(type: blocker.type)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct BlockerTypePill: View {
    let type: BlockerType

    var body: some View {
        Text(type.label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pillColor.opacity(0.15))
            .foregroundStyle(pillColor)
            .clipShape(Capsule())
    }

    private var pillColor: Color {
        switch type {
        case .practical:     return .blue
        case .informational: return .orange
        case .emotional:     return .purple
        }
    }
}
