import SwiftUI

struct BrainDumpView: View {
    @Binding var path: NavigationPath
    @Binding var retryText: String

    @AppStorage("draft_brain_dump") private var draft: String = ""
    @State private var isLoading = false
    @State private var clarificationPrompt: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unstuck")
                        .font(.largeTitle)
                        .fontWeight(.bold)

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
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isLoading ? "Thinking..." : "Next")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
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
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        clarificationPrompt = nil

        Task {
            do {
                let result = try await AIService.shared.extract(from: trimmed)
                await MainActor.run {
                    isLoading = false
                    if result.isActionable {
                        path.append(AppDestination.reflection(result))
                    } else {
                        clarificationPrompt = result.clarificationPrompt
                    }
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
