//
//  UnstickitTests.swift
//  UnstickitTests
//
//  Created by David Rynn on 3/15/26.
//
//  Flow-redesign T10. These lock in the deterministic behavior the redesign
//  depends on. The on-device FoundationModels calls (extract / clarify /
//  generateNextStep) are non-deterministic and require Apple Intelligence, so
//  they are exercised by the live verification recorded in the spec rather than
//  here; what we *can* pin down — storage/badge, defer rules, navigation state,
//  view-model logic, and the AI *schema* contract — is covered below.

import Foundation
import SwiftUI
import Testing
@testable import Unstickit

// MARK: - Helpers

@MainActor
private func makeStore() -> RecommendedStepStore {
    RecommendedStepStore(defaults: makeTransientDefaults())
}

/// A throwaway, isolated defaults suite so tests never collide or persist.
private func makeTransientDefaults() -> UserDefaults {
    let suite = "test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

/// A gregorian calendar pinned to UTC so date math is deterministic across machines.
private var utcCalendar: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}

private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    utcCalendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

private func sampleExtraction(summary: String = "You want to finish your app, but bugs keep blocking the next step.") -> ExtractionResult {
    ExtractionResult(
        isActionable: true,
        clarificationPrompt: nil,
        goalSummary: "Finish the app",
        blockers: [Blocker(description: "The code won't compile", type: .practical)],
        frictionSummary: "Each error makes the next step feel unclear.",
        summary: summary
    )
}

// MARK: - Save behavior + Saved badge (T10: store + badge)

@MainActor
struct SaveBehaviorTests {
    @Test func deferredStepDoesNotInflateSavedBadge() {
        let store = makeStore()
        store.deferUntilTomorrow(text: "A deferred step.", fallbackText: nil, brainDump: "dump")

        // The badge counts intentionally-saved steps only (spec §13).
        #expect(store.savedSteps.isEmpty)
        #expect(store.activeSteps.count == 1)
    }

    @Test func dismissRemovesSavedStep() {
        let store = makeStore()
        store.saveStep(text: "Keep me", fallbackText: nil, brainDump: "dump")
        let saved = try! #require(store.savedSteps.first)

        store.dismiss(saved)
        #expect(store.savedSteps.isEmpty)
    }
}

// MARK: - Completed-session retention (retain_completed_sessions_spec.md)

@MainActor
struct CompletedRetentionTests {
    @Test func completeMarksRecordCompletedAndRetainsIt() throws {
        let store = makeStore()
        let id = try #require(store.recordSession(text: "Do the thing", fallbackText: nil, brainDump: "dump"))

        store.complete(id: id)

        #expect(store.activeSteps.isEmpty)                 // drops out of the Recent tab
        let completed = store.steps.filter { $0.status == .completed }
        #expect(completed.count == 1)
        #expect(completed.first?.completedAt != nil)
    }

    @Test func purgeExpiredPreservesCompletedRecords() throws {
        let store = makeStore()
        let id = try #require(store.recordSession(text: "Finished step", fallbackText: nil, brainDump: "dump"))
        store.complete(id: id)

        store.purgeExpired()
        #expect(store.steps.contains { $0.status == .completed })
    }

    @Test func completedRecordsDoNotCountAgainstOpenLoopCap() throws {
        let store = makeStore()
        // Complete one session, then add 20 fresh open loops. The 20-record cap applies
        // only to active open loops, so the completed record must survive alongside them.
        let completedID = try #require(store.recordSession(text: "Completed", fallbackText: nil, brainDump: "dump"))
        store.complete(id: completedID)
        for i in 0..<20 {
            store.recordSession(text: "Open loop \(i)", fallbackText: nil, brainDump: "dump")
        }

        store.purgeExpired()

        #expect(store.activeSteps.count == 20)
        #expect(store.steps.contains { $0.status == .completed })
    }

    @Test func decodesLegacyRecordWithoutCompletedAt() throws {
        // A record persisted before `completedAt` existed must still decode (→ nil),
        // matching the store's default JSONDecoder.
        let legacy = """
        [{
          "id": "\(UUID().uuidString)",
          "text": "Legacy step",
          "source": "nextStep",
          "createdAt": 0,
          "status": "active",
          "isSaved": false
        }]
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([RecommendedStep].self, from: legacy)
        #expect(decoded.count == 1)
        #expect(decoded.first?.text == "Legacy step")
        #expect(decoded.first?.completedAt == nil)
    }
}

// MARK: - Saved-tab badge: "new since last seen", not a running total

@MainActor
struct SavedBadgeTests {
    @Test func unseenCountClearsWhenSavedTabIsSeen() {
        let store = makeStore()
        #expect(store.unseenSavedCount == 0)

        store.saveStep(text: "A new step", fallbackText: nil, brainDump: "dump")
        #expect(store.unseenSavedCount == 1)

        // Opening the Saved tab marks everything current as seen → badge clears.
        store.markSavedSeen()
        #expect(store.unseenSavedCount == 0)
        #expect(store.savedSteps.count == 1)  // the step itself stays in the list
    }

    @Test func stepsSavedAfterViewingBadgeAgain() {
        let store = makeStore()
        store.saveStep(text: "First", fallbackText: nil, brainDump: "dump")
        store.markSavedSeen()
        #expect(store.unseenSavedCount == 0)

        store.saveStep(text: "Second", fallbackText: nil, brainDump: "dump")
        #expect(store.unseenSavedCount == 1)
    }

    @Test func lastSeenPersistsAcrossInstances() {
        let defaults = makeTransientDefaults()
        let first = RecommendedStepStore(defaults: defaults)
        first.saveStep(text: "Saved", fallbackText: nil, brainDump: "dump")
        first.markSavedSeen()
        #expect(first.unseenSavedCount == 0)

        // A relaunch must not resurrect the badge for already-seen steps.
        let reloaded = RecommendedStepStore(defaults: defaults)
        #expect(reloaded.savedSteps.count == 1)
        #expect(reloaded.unseenSavedCount == 0)
    }
}

// MARK: - Deferred ("Come back tomorrow") flow — T9 storage contract

@MainActor
struct DeferredStepTests {
    @Test func deferCreatesOneUnsavedDeferredStep() {
        let store = makeStore()
        store.deferUntilTomorrow(text: "Describe the bug.", fallbackText: "Open the file.", brainDump: "dump")

        #expect(store.activeSteps.count == 1)
        let step = try! #require(store.activeSteps.first)
        #expect(step.source == .deferredTomorrow)
        #expect(step.isSaved == false)
        #expect(step.isDeferred)
        #expect(step.expiresAt != nil)
    }

    @Test func deferReturnsAvailabilityAtLeastSixHoursOut() {
        let store = makeStore()
        let before = Date()
        let availableOn = store.deferUntilTomorrow(text: "Step", fallbackText: nil, brainDump: "dump")
        // come_back_tomorrow_spec.md §6: never sooner than 6 hours after creation.
        #expect(availableOn >= before.addingTimeInterval(6 * 60 * 60))
    }

    @Test func availabilityIsNextDayFiveAMWhenDeferringEarly() {
        // Deferring at 01:00 → 5 AM the next day wins over the +6h floor (07:00 same day).
        let created = date(2026, 6, 19, 1, 0)
        let result = RecommendedStepStore.nextTomorrowAvailability(from: created, calendar: utcCalendar)
        #expect(result == date(2026, 6, 20, 5, 0))
    }

    @Test func availabilityRespectsSixHourFloorWhenDeferringLateNight() {
        // Deferring at 23:30 → next-day 5 AM (05:00) is sooner than +6h (05:30), so the
        // 6-hour floor wins.
        let created = date(2026, 6, 19, 23, 30)
        let result = RecommendedStepStore.nextTomorrowAvailability(from: created, calendar: utcCalendar)
        #expect(result == created.addingTimeInterval(6 * 60 * 60))
        #expect(result == date(2026, 6, 20, 5, 30))
    }

    @Test func dueDeferredStepIsNilUntilAvailable() {
        // A freshly deferred step (availableOn in the future) must not interrupt S1 (§9).
        let store = makeStore()
        store.deferUntilTomorrow(text: "Step", fallbackText: nil, brainDump: "dump")
        #expect(store.dueDeferredStep == nil)
    }

    @Test func dueDeferredStepSurfacesWhenAvailableOnHasPassed() {
        // Seed a deferred step whose availability has already passed, as if the user
        // returned the next day, and confirm it surfaces for the return card (§7).
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let dueStep = RecommendedStep(
            id: UUID(),
            text: "Pick this back up.",
            fallbackText: "Just open the file.",
            source: .deferredTomorrow,
            originalBrainDump: "dump",
            createdAt: Date().addingTimeInterval(-86_400),
            availableOn: Date().addingTimeInterval(-3_600),  // 1 hour ago → due
            expiresAt: Date().addingTimeInterval(6 * 86_400),
            status: .active,
            isSaved: false
        )
        defaults.set(try! JSONEncoder().encode([dueStep]), forKey: "recommended_steps")

        let store = RecommendedStepStore(defaults: defaults)
        let due = try! #require(store.dueDeferredStep)
        #expect(due.id == dueStep.id)
        #expect(due.source == .deferredTomorrow)
    }

    @Test func expiredUnsavedStepIsPurgedOnLoad() {
        // come_back_tomorrow_spec.md §9: expired, unsaved steps auto-delete.
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let expired = RecommendedStep(
            id: UUID(),
            text: "Old step",
            fallbackText: nil,
            source: .deferredTomorrow,
            originalBrainDump: "dump",
            createdAt: Date().addingTimeInterval(-8 * 86_400),
            availableOn: Date().addingTimeInterval(-7 * 86_400),
            expiresAt: Date().addingTimeInterval(-86_400),  // expired yesterday
            status: .active,
            isSaved: false
        )
        defaults.set(try! JSONEncoder().encode([expired]), forKey: "recommended_steps")

        let store = RecommendedStepStore(defaults: defaults)
        #expect(store.activeSteps.isEmpty)
    }
}

// MARK: - NextStepModel logic (T8/T9 behavior)

@MainActor
struct NextStepModelTests {
    private func model(store: RecommendedStepStore) -> NextStepModel {
        NextStepModel(
            result: NextStepResult(nextStep: "Step text", fallbackStep: "Smaller step"),
            brainDump: "I'm stuck.",
            store: store
        )
    }

    @Test func stillStuckRevealsSmallerStep() {
        let m = model(store: makeStore())
        #expect(m.fallbackRevealed == false)

        // Reveal-only now — surfaces the smaller step, never restarts the flow.
        m.revealSmallerStep()
        #expect(m.fallbackRevealed == true)
    }

    @Test func recordSessionPersistsOneSilentOpenLoop() {
        let store = makeStore()
        let m = model(store: store)

        m.recordSession()

        // Persisted as history, not an intentional save — so the Saved badge stays 0.
        #expect(store.activeSteps.count == 1)
        #expect(store.savedSteps.isEmpty)
    }

    @Test func recordSessionIsIdempotent() {
        let store = makeStore()
        let m = model(store: store)

        m.recordSession()
        m.recordSession()

        #expect(store.activeSteps.count == 1)
    }

    @Test func completeSessionRetainsRecordAsCompleted() {
        let store = makeStore()
        let m = model(store: store)
        m.recordSession()

        // "Got it" completes the loop: it leaves the open-loop list (so the Recent tab
        // no longer shows it) but is retained — status .completed, timestamped — rather
        // than deleted (retain_completed_sessions_spec.md).
        m.completeSession()
        #expect(store.activeSteps.isEmpty)
        let completed = store.steps.filter { $0.status == .completed }
        #expect(completed.count == 1)
        #expect(completed.first?.completedAt != nil)
    }

    @Test func discardSessionDeletesTheOpenLoop() {
        let store = makeStore()
        let m = model(store: store)
        m.recordSession()

        // "Delete & start over" (and the defer hand-off) discard the session entirely —
        // nothing is retained.
        m.discardSession()
        #expect(store.activeSteps.isEmpty)
        #expect(store.steps.isEmpty)
    }

    @Test func deferHandOffDiscardsRatherThanCompletes() {
        let store = makeStore()
        let m = model(store: store)

        // The come-back-tomorrow sheet's onDismiss routes through discard (not complete),
        // so deferring leaves the deferred record and creates no spurious .completed one.
        m.comeBackTomorrow()
        m.discardSession()

        #expect(!store.steps.contains { $0.status == .completed })
        #expect(store.activeSteps.contains { $0.source == .deferredTomorrow })
    }

    @Test func comeBackTomorrowDefersAndShowsConfirmation() {
        let store = makeStore()
        let m = model(store: store)

        m.comeBackTomorrow()

        #expect(m.deferConfirmationShown == true)
        #expect(store.activeSteps.count == 1)
        #expect(store.activeSteps.first?.source == .deferredTomorrow)
        // Deferring must not touch the Saved badge.
        #expect(store.savedSteps.isEmpty)
    }
}

// MARK: - Navigation state (T5 rewiring)

@MainActor
struct AppNavigationTests {
    @Test func startUnstickFreshResetsBothPathsAndSelectsUnstick() {
        let nav = AppNavigation()
        nav.selectedTab = .saved
        nav.unstickPath.append(AppDestination.nextStep(
            NextStepResult(nextStep: "s", fallbackStep: "f"), brainDump: "d"
        ))
        nav.savedPath.append("anything")

        nav.startUnstickFresh()

        #expect(nav.unstickPath.isEmpty)
        #expect(nav.savedPath.isEmpty)
        #expect(nav.selectedTab == .unstick)
    }

    @Test func retryCarriesBrainDumpAndReturnsToFreshUnstick() {
        let nav = AppNavigation()
        nav.selectedTab = .saved

        nav.retry(with: "my original text")

        #expect(nav.retryBrainDump == "my original text")
        #expect(nav.selectedTab == .unstick)
        #expect(nav.unstickPath.isEmpty)
    }
}

// MARK: - Reflection + Choice model (T4/T7 — no model call)

@MainActor
struct ReflectionChoiceModelTests {
    @Test func initWithClarificationExposesOptions() {
        let clarification = ClarificationResult(options: [
            ClarificationOption(label: "I keep trying fixes.", mode: .reproduce),
            ClarificationOption(label: "I'm not sure where to start.", mode: .narrow),
            ClarificationOption(label: "I feel overwhelmed.", mode: .clarify),
        ])
        let m = ReflectionChoiceModel(extraction: sampleExtraction(), clarification: clarification, brainDump: "dump", nav: AppNavigation(), sessionLog: SessionLogStore(defaults: makeTransientDefaults()))

        #expect(m.options.count == 3)
        #expect(m.optionsFailed == false)
        #expect(m.isBusy == false)
    }

    @Test func initWithNilClarificationFlagsFailureForRetry() {
        // T7: clarification failed but extraction succeeded → screen shows summary + retry.
        let m = ReflectionChoiceModel(extraction: sampleExtraction(), clarification: nil, brainDump: "dump", nav: AppNavigation(), sessionLog: SessionLogStore(defaults: makeTransientDefaults()))
        #expect(m.options.isEmpty)
        #expect(m.optionsFailed == true)
    }
}

// MARK: - AI schema contract (T10: fail loudly if the schema regresses)

struct AIContractTests {
    @Test func extractionResultExposesSummaryField() {
        // If `summary` is removed from ExtractionResult this test stops compiling —
        // the redesign's S2 display line (spec §6) depends on it.
        let extraction = sampleExtraction(summary: "A concise second-person line.")
        #expect(extraction.summary == "A concise second-person line.")
    }

    @Test func clarificationResultHoldsOptions() {
        let result = ClarificationResult(options: [
            ClarificationOption(label: "x", mode: .reproduce)
        ])
        #expect(result.options.count == 1)
    }

    @Test func stuckModeHasExactlyThreeKnownCases() {
        // Stage 2 must produce one option per StuckMode (spec §6), and `clarify`'s
        // mode-coverage repair relies on `allModes`. This pins the mode set: adding or
        // removing a case breaks the exhaustive switch below at compile time.
        for mode in StuckMode.allModes {
            switch mode {
            case .reproduce, .narrow, .clarify:
                break  // exhaustive — a new case forces this test to be updated
            }
        }
        #expect(StuckMode.allModes.count == 3)
        #expect(Set(StuckMode.allModes.map(\.rawValue)) == ["reproduce", "narrow", "clarify"])
    }
}

// MARK: - Stage 3 step validation (known_issues.md #2: "Write one thing…" repetition)

struct StepValidationTests {
    @Test func acceptsAShortSingleSentenceStep() {
        let failure = AIService.validationFailure(
            for: "Open the spreadsheet and read just the first row."
        )
        #expect(failure == nil)
    }

    @Test func rejectsEmptyOutput() {
        #expect(AIService.validationFailure(for: "   ") == .empty)
    }

    @Test func rejectsMultipleLines() {
        let failure = AIService.validationFailure(
            for: "Open the file.\nRead the first function."
        )
        #expect(failure == .multiLine)
    }

    @Test func rejectsMoreThanTwentyFiveWordsPastTheThirtyFiveWordSlack() {
        let longStep = Array(repeating: "word", count: 40).joined(separator: " ") + "."
        #expect(AIService.validationFailure(for: longStep) == .tooManyWords)
    }

    @Test func rejectsMoreThanOneSentence() {
        // The known reproduce-mode failure mode called out in the code comment.
        let failure = AIService.validationFailure(
            for: "List what you tried. Then pick one."
        )
        #expect(failure == .multiSentence)
    }

    @Test func rejectsAnExactEchoOfAForbiddenPhrase() {
        let failure = AIService.validationFailure(
            for: "Open the file where the error happens and read just the first function."
        )
        #expect(failure == .forbiddenPhrase)
    }

    @Test func rejectsANearTotalEchoOfAForbiddenPhraseDespiteCasingAndPunctuationDifferences() {
        let failure = AIService.validationFailure(
            for: "open the FILE where the error happens, and read just the first function"
        )
        #expect(failure == .forbiddenPhrase)
    }

    @Test func acceptsALegitimateStepThatOnlyCoincidentallySharesAFewWordsWithAForbiddenPhrase() {
        // Regression test for the loosened anti-copy guard (known_issues.md #2): plain
        // substring containment used to reject any short output that overlapped a forbidden
        // phrase at all, even without being an echo of it.
        let failure = AIService.validationFailure(
            for: "Open the file and skim the summary at the top."
        )
        #expect(failure == nil)
    }
}

// MARK: - Session log (session_log_spec.md)

@MainActor
struct SessionLogStoreTests {
    @Test func recordAppendsOneEntryWithTruncatedSnippet() {
        let store = SessionLogStore(defaults: makeTransientDefaults())
        store.record(brainDump: "I can't get my app finished", chosenMode: .narrow, blockerTypes: [.practical, .emotional])

        #expect(store.entries.count == 1)
        let entry = store.entries[0]
        #expect(entry.chosenMode == .narrow)
        #expect(entry.blockerTypes == [.practical, .emotional])
        #expect(entry.brainDumpSnippet == "I can't get my app finished")
    }

    @Test func snippetCollapsesWhitespaceAndTruncatesLongDumps() {
        let long = String(repeating: "stuck ", count: 40)  // > 84 chars once collapsed
        let snippet = SessionLogEntry.snippet(from: long)
        #expect(snippet.count <= 84 + 3)        // cap + ellipsis
        #expect(snippet.hasSuffix("..."))
        #expect(!snippet.contains("  "))        // whitespace collapsed
    }

    @Test func logIsAppendOnlyAndPersistsAcrossInstances() {
        let defaults = makeTransientDefaults()
        let first = SessionLogStore(defaults: defaults)
        first.record(brainDump: "one", chosenMode: .reproduce, blockerTypes: [.informational])
        first.record(brainDump: "two", chosenMode: .clarify, blockerTypes: [])

        // A fresh store over the same defaults sees both entries, in order.
        let reloaded = SessionLogStore(defaults: defaults)
        #expect(reloaded.entries.count == 2)
        #expect(reloaded.entries.map(\.brainDumpSnippet) == ["one", "two"])
    }
}

// MARK: - Navigation destinations (T5 contract)

struct AppDestinationTests {
    @Test func reflectionChoiceAndNextStepAreDistinct() {
        let extraction = sampleExtraction()
        let clarification = ClarificationResult(options: [
            ClarificationOption(label: "x", mode: .reproduce)
        ])
        let choice = AppDestination.reflectionChoice(
            extraction: extraction, clarification: clarification, brainDump: "d"
        )
        let step = AppDestination.nextStep(
            NextStepResult(nextStep: "s", fallbackStep: "f"), brainDump: "d"
        )
        #expect(choice != step)

        // reflectionChoice carries an optional clarification (nil on the T7 failure path).
        let choiceNoOptions = AppDestination.reflectionChoice(
            extraction: extraction, clarification: nil, brainDump: "d"
        )
        #expect(choiceNoOptions != choice)
    }
}
