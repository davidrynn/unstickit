import SwiftUI

struct ContentView: View {
    var body: some View {
        if AIService.shared.isAvailable() {
            RootTabView()
        } else {
            AIRequiredView()
        }
    }
}
