import SwiftUI

struct FullScreenPauseLoaderOverlay: View {
    let message: String
    var dotCount: Int = 180

    var body: some View {
        Rectangle()
            .fill(.thinMaterial)
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
