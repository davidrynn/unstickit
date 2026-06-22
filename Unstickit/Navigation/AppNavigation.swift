import Observation
import SwiftUI

/// The two top-level tabs in the app shell.
enum AppTab {
    case unstick
    case saved
}

/// Shared navigation state for the tab shell. Owning tab selection and each
/// tab's path in one observable object lets descendant views drive cross-tab
/// navigation by mutating state (the SwiftUI way) instead of via callbacks.
@MainActor
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .unstick
    var unstickPath = NavigationPath()
    var savedPath = NavigationPath()

    /// The full-screen loader's message, or `nil` when no loader is shown. Owning
    /// it here (rather than per-screen `@State`) lets a loader that precedes a
    /// navigation stay up *through* the push: the screen that starts the work sets
    /// it, and the **destination clears it in its own `.onAppear`** — so it is
    /// dismissed only once the next screen has mounted. The overlay is rendered once
    /// at the tab-shell root. Always paired with `pushBehindLoader` so the push is
    /// non-animated: the destination snaps into place under the opaque loader, and
    /// fading the loader reveals a settled screen rather than a slide transition.
    var loadingMessage: String?

    /// Brain-dump text carried over from "I'm still stuck" so the dump screen
    /// can repopulate the editor on the next appearance.
    var retryBrainDump = ""

    /// Return to a fresh Unstick tab, clearing any in-progress navigation in
    /// both tabs. Used by "Start" (Saved tab) and "Start this step"
    /// (`NextStepView`); resetting both paths is robust regardless of which
    /// stack the caller was in. The saved step itself stays in the list
    /// (recommended-steps spec §4 — Start leaves it until it expires, is saved,
    /// or is dismissed).
    func startUnstickFresh() {
        unstickPath = NavigationPath()
        savedPath = NavigationPath()
        selectedTab = .unstick
        loadingMessage = nil
    }

    /// Restart the dump flow with the prior text preserved (the "I'm still
    /// stuck" retry). The dump lives in the Unstick tab, so route there
    /// regardless of where the retry originated.
    func retry(with text: String) {
        retryBrainDump = text
        startUnstickFresh()
    }

    /// Push a destination with the system push transition **disabled**, for the
    /// case where a full-screen loader is already covering the screen. With the
    /// animation off, the destination mounts instantly behind the loader; the
    /// destination's `.onAppear` then clears `loadingMessage`, and the loader fades
    /// to reveal an already-settled screen. This avoids the brief flash of the
    /// slide transition (and the prior screen) that occurs if the loader fades out
    /// while an animated push is still running underneath it.
    func pushBehindLoader(_ destination: AppDestination, path: Binding<NavigationPath>) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            path.wrappedValue.append(destination)
        }
    }
}
