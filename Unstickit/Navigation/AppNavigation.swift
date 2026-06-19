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
    }

    /// Restart the dump flow with the prior text preserved (the "I'm still
    /// stuck" retry). The dump lives in the Unstick tab, so route there
    /// regardless of where the retry originated.
    func retry(with text: String) {
        retryBrainDump = text
        startUnstickFresh()
    }
}
