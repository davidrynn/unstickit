import SwiftUI

struct ContentView: View {
    var body: some View {
        let availability = AIService.shared.availability()
        if availability == .available {
            RootTabView()
        } else {
            AIRequiredView(availability: availability)
        }
    }
}
