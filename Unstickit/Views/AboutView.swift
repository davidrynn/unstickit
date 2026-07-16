import SwiftUI

/// Lightweight About / privacy screen, presented as a sheet from the Brain Dump
/// screen's info button. Surfaces the on-device privacy thesis where the user
/// actually is, plus the App Review-required support & privacy links and the build
/// version. There are no settings to configure in 1.0 — this is informational only.
/// (See app_store_release_assets_spec.md §7 for the URLs it should link to.)
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    // Dedicated stable pages (see Docs/support_page/PAGE_SPEC.md §2) so each link — and each
    // App Store Connect field — lands directly on the right content. Both must stay reachable,
    // and the policy wording must match this sheet + the "Data Not Collected" App Store label.
    private let supportURL = URL(string: "https://davidrynn.com/clear-next-step/support")
    private let privacyURL = URL(string: "https://davidrynn.com/clear-next-step/privacy")
    /// Companion custom GPT (known_issues.md #6) — same flow on a full-size LLM. Framed as
    /// a companion experiment, not a replacement, and flagged as leaving the device since
    /// the app's whole privacy thesis is on-device.
    private let webGPTURL = URL(string: "https://chatgpt.com/g/g-69c70cfdb3d48191a63d67edb52b3cee-clear-next-step")

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Private by design", systemImage: "lock.fill")
                            .font(.headline)
                        Text("Everything you write stays on your iPhone. Clear Next Step runs on-device with Apple Intelligence — no account, no cloud, nothing uploaded. Your words never leave your phone.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Runs on Apple Intelligence", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                        Text("Clear Next Step needs an iPhone 15 Pro or later with Apple Intelligence turned on.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if supportURL != nil || privacyURL != nil {
                        VStack(alignment: .leading, spacing: 14) {
                            if let supportURL {
                                Link("Support", destination: supportURL)
                            }
                            if let privacyURL {
                                Link("Privacy Policy", destination: privacyURL)
                            }
                        }
                        .font(.body)
                    }

                    if let webGPTURL {
                        VStack(alignment: .leading, spacing: 8) {
                            Link("Want to try this on a full LLM on the web?", destination: webGPTURL)
                                .font(.subheadline)
                            Text("The companion GPT runs on OpenAI's servers, under a separate privacy policy — unlike the app, your words leave your device.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom) {
                Text(versionText)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AboutView()
}
