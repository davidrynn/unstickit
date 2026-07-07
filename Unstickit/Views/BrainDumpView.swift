import SwiftUI

struct BrainDumpView: View {
    @Binding var path: NavigationPath

    @EnvironmentObject private var stepStore: RecommendedStepStore
    @Environment(AppNavigation.self) private var nav
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("draft_brain_dump") private var draft: String = ""
    @State private var clarificationPrompt: String? = nil
    @State private var errorMessage: String? = nil
    @State private var showAbout = false
    @State private var deferredCardDismissed = false
    /// Drives keyboard dismissal: the writing area is a multi-line editor, so Return
    /// inserts a newline rather than dismissing. A keyboard-toolbar "Done" resigns this.
    @FocusState private var isEditorFocused: Bool

    /// The loader is shared state now (see `AppNavigation.loadingMessage`) so it can
    /// persist across the push to the choice screen; this screen only reads it.
    private var isLoading: Bool { nav.loadingMessage != nil }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Blue hero-wordmark color, adapted to appearance (hero_wordmark_animation_spec.md):
    /// a deeper blue on the light background, a lighter/airier blue on the dark one.
    private var sandBlue: Color {
        colorScheme == .dark
            ? Color(red: 0.40, green: 0.68, blue: 1.0)
            : Color(red: 0.10, green: 0.36, blue: 0.85)
    }

    var body: some View {
        // Fixed layout (no outer ScrollView): the writing area takes the whole
        // remaining height and scrolls internally, so the page never shifts and
        // the action button stays pinned and visible (flow_redesign_spec.md §4).
        VStack(spacing: 0) {
            // Soft return point for a step deferred yesterday
            // (come_back_tomorrow_spec.md §7). Shown above the prompt.
            if let deferred = stepStore.dueDeferredStep, !deferredCardDismissed {
                DeferredReturnCard(
                    step: deferred,
                    onStart: { deferredCardDismissed = true },
                    onLetGo: {
                        stepStore.dismiss(deferred)
                        deferredCardDismissed = true
                    }
                )
                .padding(.bottom, 20)
            }

            VStack(alignment: .center, spacing: 16) {
                SandTextView(text: "Clear Next Step",
                             seed: 23,
                             dotCount: 400,
                             dotColor: sandBlue,
                             backgroundColor: .clear)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: 6) {
                    Text("What are you stuck on?")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Write whatever comes to mind")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            brainDumpEditor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Pin the primary action (and any submit feedback) to the bottom: always
        // reachable without scrolling, and above the tab bar / keyboard.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if let prompt = clarificationPrompt {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.tint)
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    Text(isLoading ? "Thinking..." : "Find my next step")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        // Same blue as the wordmark; softened (not flat grey) when
                        // disabled so the resting screen still reads "in the family."
                        .background(trimmedDraft.isEmpty ? sandBlue.opacity(0.35) : sandBlue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(trimmedDraft.isEmpty || isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            // Breathing room so the button doesn't crowd the floating tab bar.
            .padding(.bottom, 16)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.18 : 1)
        .animation(.easeInOut(duration: 0.14), value: isLoading)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAbout = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("About Clear Next Step")
            }
            // A multi-line editor has no "return = done", so give the keyboard an
            // explicit Done that resigns first responder and reveals the pinned
            // "Find my next step" button beneath it.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEditorFocused = false }
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                stepStore.purgeExpired()
            }
            // Apply retry text from "I'm still stuck" (second tap)
            if !nav.retryBrainDump.isEmpty {
                draft = nav.retryBrainDump
                nav.retryBrainDump = ""
            }
            clarificationPrompt = nil
            errorMessage = nil
        }
    }

    /// The writing area. Fills the space handed to it and scrolls internally, so
    /// the surrounding layout stays fixed. Shows a quiet placeholder while empty
    /// so the box reads as an invitation rather than a void, and carries a light
    /// border so the tap target is legible against the page.
    private var brainDumpEditor: some View {
        ZStack(alignment: .topLeading) {
            if draft.isEmpty {
                Text("e.g. I keep meaning to start, but every time I sit down I get overwhelmed and end up doing something else.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    // Matches TextEditor's internal text-container inset so the
                    // placeholder sits exactly where typing begins.
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $draft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .disabled(isLoading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator).opacity(0.6), lineWidth: 1)
        )
        // Quiet in-field clear: empties the writing area so it's easy to start over.
        // No confirmation — it's a clear, not a "delete everything." Sits at the
        // trailing *end* of the box (bottom-right), following the text-field clear
        // pattern adapted for a multi-line editor — the top-right corner is where the
        // first line of text flows, so a button there would cover what's being typed.
        // Only shown when there's something to clear and we're not mid-generation.
        .overlay(alignment: .bottomTrailing) {
            if !draft.isEmpty && !isLoading {
                Button(action: clearDraft) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        // Backing circle so the glyph stays legible over any text
                        // that scrolls up beneath it.
                        .background(Color(.secondarySystemBackground), in: Circle())
                        .padding(6)
                }
                .accessibilityLabel("Clear text")
            }
        }
    }

    private func clearDraft() {
        draft = ""
        clarificationPrompt = nil
        errorMessage = nil
    }

    private func submit() {
        guard !trimmedDraft.isEmpty else { return }
        // Reentry guard: a fast double-tap could fire submit twice before the button
        // disables / the loader overlay covers the screen, double-pushing the next screen.
        guard nav.loadingMessage == nil else { return }
        let trimmed = trimmedDraft

        let wordCount = trimmed.split(whereSeparator: \.isWhitespace).count
        if wordCount < 4 {
            clarificationPrompt = "Tell me a bit more — what are you working on, and what's making it hard to move forward?"
            return
        }

        // Show the shared loader and keep it up across the push: the destination
        // (`ReflectionChoiceView`) clears `nav.loadingMessage` in its `.onAppear`,
        // so it never blinks off mid-transition.
        nav.loadingMessage = "Working on your reflection..."
        errorMessage = nil
        clarificationPrompt = nil

        Task {
            do {
                // Run extraction + clarification-option generation behind one loader,
                // then navigate straight to the combined Reflection + Choice screen.
                let extraction = try await AIService.shared.extract(from: trimmed)

                guard extraction.isActionable else {
                    nav.loadingMessage = nil
                    clarificationPrompt = extraction.clarificationPrompt
                    return
                }

                // Hold the loader through clarification. If it fails (but extraction
                // succeeded), still advance to the choice screen with the summary and
                // let that screen offer a retry — don't dead-end on the dump.
                let clarification = try? await AIService.shared.clarify(extraction: extraction)
                // Non-animated push so the loader hides the navigation entirely
                // (cleared by ReflectionChoiceView.onAppear).
                nav.pushBehindLoader(
                    .reflectionChoice(
                        extraction: extraction,
                        clarification: clarification,
                        brainDump: trimmed
                    ),
                    path: $path
                )
            } catch {
                nav.loadingMessage = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Lightweight return affordance for a step the user deferred yesterday
/// (come_back_tomorrow_spec.md §7). Collapsed to one quiet line by default so it
/// never competes with the brain dump (flow_redesign_spec.md §4); tapping the row
/// expands the actions. **Start** and **Make it smaller** are a free resume and are
/// never paywalled (flow_redesign_spec.md §14).
private struct DeferredReturnCard: View {
    let step: RecommendedStep
    let onStart: () -> Void
    let onLetGo: () -> Void

    @State private var expanded = false
    @State private var showSmaller = false

    var body: some View {
        VStack(alignment: .leading, spacing: expanded ? 12 : 0) {
            // Quiet header row — tap to expand/collapse.
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.uturn.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(expanded ? "Ready to pick this back up?" : "Pick up your step")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Text(step.text)
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showSmaller, let fallbackText = step.fallbackText {
                    Text(fallbackText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 16) {
                    Button(action: onStart) {
                        Text("Start")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    // Only when a smaller step exists; never regenerate from here (§7).
                    if step.fallbackText != nil && !showSmaller {
                        Button("Make it smaller") {
                            withAnimation(.easeInOut(duration: 0.2)) { showSmaller = true }
                        }
                        .font(.subheadline)
                    }

                    Spacer()

                    Button("Let this go", role: .destructive, action: onLetGo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(expanded ? 16 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
#Preview {
    // Provide required bindings and environment so the view can render.
    let store = RecommendedStepStore()
    let nav = AppNavigation()
    return NavigationStack {
        BrainDumpView(path: .constant(NavigationPath()))
            .environmentObject(store)
            .environment(nav)
    }
}
