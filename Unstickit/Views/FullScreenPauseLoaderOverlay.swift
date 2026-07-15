import SwiftUI

struct FullScreenPauseLoaderOverlay: View {
    let message: String
    var dotCount: Int = 180

    var body: some View {
        // Fully opaque on purpose: this overlay is a curtain for the navigation that
        // happens behind it (`AppNavigation.pushBehindLoader`). A translucent material
        // here let the outgoing and incoming screens cross-fade in view — both visible
        // at once during the handoff.
        Rectangle()
            .fill(Color(.systemBackground))
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LoadingPauseStreamView(seed: 41,
                                           dotCount: dotCount,
                                           axis: .vertical,
                                           dotColor: .primary,
                                           backgroundColor: .clear)
                        .frame(width: 42, height: 240)
                }
                .padding(24)
                .frame(maxWidth: 260)
            }
    }
}
