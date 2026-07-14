import SwiftUI

struct ContentView: View {
    var body: some View {
        let availability = AIService.shared.availability()
        #if DEBUG
        if ProcessInfo.processInfo.environment["UI_BYPASS_AI_GATE"] == "1" {
            RootTabView()
        } else if availability == .available {
            RootTabView()
        } else {
            AIRequiredView(availability: availability)
        }
        #else
        if availability == .available {
            RootTabView()
        } else {
            AIRequiredView(availability: availability)
        }
        #endif
    }
}
