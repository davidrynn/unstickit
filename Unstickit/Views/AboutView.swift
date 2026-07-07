import SwiftUI

/// Lightweight About / privacy screen, presented as a sheet from the Brain Dump
/// screen's info button. Surfaces the on-device privacy thesis where the user
/// actually is, plus the App Review-required support & privacy links and the build
/// version. There are no settings to configure in 1.0 — this is informational only.
/// (See app_store_release_assets_spec.md §7 for the URLs it should link to.)
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    // One page covers both sections (see Docs/support_page/PAGE_SPEC.md); the Support and
    // Privacy links point at it. Must stay reachable for App Review, and the privacy wording
    // there must match this sheet + the "Data Not Collected" App Store label.
    private let supportURL = URL(string: "https://davidrynn.com/clear-next-step/")
    private let privacyURL = URL(string: "https://davidrynn.com/clear-next-step/")

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
