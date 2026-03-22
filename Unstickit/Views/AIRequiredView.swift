import SwiftUI

struct AIRequiredView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "brain")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("Apple Intelligence Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("Unstuck uses on-device Apple Intelligence to help you find your next step. This requires an iPhone 15 Pro or later with Apple Intelligence enabled.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(32)
    }
}

#Preview {
    AIRequiredView()
}
