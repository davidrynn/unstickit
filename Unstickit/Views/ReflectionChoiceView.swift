import SwiftUI

struct ReflectionChoiceView: View {
    let summary: String
    let brainDump: String
    @Binding var path: NavigationPath
    /// Shared loader state; held as a plain reference so the model can be built in
    /// `init` (where `@Environment` isn't yet available). Observation still tracks
    /// `nav.loadingMessage` accesses made in `body`.
    private let nav: AppNavigation
    @StateObject private var model: ReflectionChoiceModel

    /// True only while we're pushing to the next step, so `onDisappear` can tell a push
    /// (loader handed off to `NextStepView`) apart from leaving the screen (loader should
    /// be cleared). Reset on each `onAppear`.
    @State private var didPushNext = false

    private var isLoading: Bool { nav.loadingMessage != nil }

    init(
        extraction: ExtractionResult,
        clarification: ClarificationResult?,
        brainDump: String,
        path: Binding<NavigationPath>,
        nav: AppNavigation,
        sessionLog: SessionLogStore
    ) {
        self.summary = extraction.summary
        self.brainDump = brainDump
        self._path = path
        self.nav = nav
        self._model = StateObject(
            wrappedValue: ReflectionChoiceModel(
                extraction: extraction,
                clarification: clarification,
                brainDump: brainDump,
                nav: nav,
                sessionLog: sessionLog
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summaryCard

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("Which feels most true right now?")

                    if model.options.isEmpty {
                        optionsUnavailable
                    } else {
                        ForEach(model.options.indices, id: \.self) { i in
                            ChoiceRow(label: model.options[i].label) {
                                model.select(model.options[i])
                            }
                        }

                        ChoiceRow(label: "Something else") {
                            model.somethingElse()
                        }
                    }
                }

                editLink

                if let error = model.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(24)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.18 : 1)
        // Same 0.35s as the shared loader overlay so dim and loader fade as one.
        .animation(.easeInOut(duration: 0.35), value: isLoading)
        .navigationTitle("Here's what I'm hearing")
        .navigationBarTitleDisplayMode(.inline)
        // Clear the loader the inbound transition (dump → here) raised — after the
        // push has settled, so the loader never fades while two screens are moving
        // beneath it. The shared overlay lives at the tab-shell root.
        .onAppear {
            nav.dismissLoaderAfterPushSettles()
            didPushNext = false
        }
        .onChange(of: model.generatedStep) { _, step in
            guard let step else { return }
            // Non-animated push so the loader hides the navigation entirely
            // (cleared by NextStepView.onAppear).
            didPushNext = true
            nav.pushBehindLoader(.nextStep(step, brainDump: brainDump), path: $path)
            model.clearGeneratedStep()
        }
        // Safety net: if this screen goes away without having pushed the next step
        // (e.g. popped while Stage 3 was still generating), don't leave the shared
        // loader stuck. A push hands the loader off to NextStepView, so skip then.
        .onDisappear {
            if !didPushNext { nav.loadingMessage = nil }
        }
    }

    /// Shown when clarification failed: keep the summary, explain, and offer a retry.
    /// **Edit what I wrote** remains available below as the other way forward.
    private var optionsUnavailable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("I couldn't load your options just now.")
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                model.retryOptions()
            } label: {
                Text("Retry")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    /// Low-emphasis link by default; after a reroll (which adds no new signal) it
    /// becomes the nudged path, with a hint and stronger styling.
    @ViewBuilder
    private var editLink: some View {
        if model.rerollCount >= 1 {
            VStack(spacing: 8) {
                Text("Still not quite right? Editing what you wrote usually helps more than another set.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Edit what I wrote", action: editWhatIWrote)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
        } else {
            Button("Edit what I wrote", action: editWhatIWrote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Summary")
            Text(summary)
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    /// Return to the brain dump with the user's original text preserved. The dump
    /// text lives in `@AppStorage`, so popping to root is enough to keep it intact.
    private func editWhatIWrote() {
        path = NavigationPath()
    }
}

private struct ChoiceRow: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let extraction = ExtractionResult(
        isActionable: true,
        clarificationPrompt: nil,
        goalSummary: "Finish the app",
        blockers: [],
        frictionSummary: "AI/SwiftUI bugs keep getting in the way",
        summary: "You want to finish your app, but AI/SwiftUI bugs keep making the next step feel unclear."
    )
    let clarification = ClarificationResult(options: [
        ClarificationOption(label: "I keep trying fixes, but nothing works.", mode: .reproduce),
        ClarificationOption(label: "I'm not sure where to begin or what the real cause is.", mode: .narrow),
        ClarificationOption(label: "I feel overwhelmed and can't focus.", mode: .clarify)
    ])
    return NavigationStack {
        ReflectionChoiceView(
            extraction: extraction,
            clarification: clarification,
            brainDump: "I can't get my app finished",
            path: .constant(NavigationPath()),
            nav: AppNavigation(),
            sessionLog: SessionLogStore()
        )
    }
}
