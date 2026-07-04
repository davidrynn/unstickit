import SwiftUI

struct AIRequiredView: View {
    let availability: AIAvailability

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: content.icon)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text(content.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(content.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if content.showsSettingsButton {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding(32)
    }

    private var content: Content {
        switch availability {
        case .appleIntelligenceNotEnabled:
            return Content(
                icon: "brain",
                title: "Turn On Apple Intelligence",
                message: "Clear Next Step uses on-device Apple Intelligence to help you find your next step. You can turn it on in Settings whenever you're ready.",
                showsSettingsButton: true
            )
        case .modelNotReady:
            return Content(
                icon: "arrow.down.circle",
                title: "Getting Ready",
                message: "Apple Intelligence is still setting up on your device. No rush — come back in a bit.",
                showsSettingsButton: false
            )
        case .deviceNotEligible:
            return Content(
                icon: "brain",
                title: "Apple Intelligence Required",
                message: "Clear Next Step runs entirely on your device using Apple Intelligence, which this iPhone doesn't support. It needs an iPhone 15 Pro or later.",
                showsSettingsButton: false
            )
        case .unknown, .available:
            return Content(
                icon: "brain",
                title: "Apple Intelligence Required",
                message: "Clear Next Step uses on-device Apple Intelligence to help you find your next step. This requires an iPhone 15 Pro or later with Apple Intelligence enabled.",
                showsSettingsButton: true
            )
        }
    }

    private struct Content {
        let icon: String
        let title: String
        let message: String
        let showsSettingsButton: Bool
    }
}

#Preview("Not enabled") {
    AIRequiredView(availability: .appleIntelligenceNotEnabled)
}

#Preview("Device not eligible") {
    AIRequiredView(availability: .deviceNotEligible)
}

#Preview("Model not ready") {
    AIRequiredView(availability: .modelNotReady)
}
