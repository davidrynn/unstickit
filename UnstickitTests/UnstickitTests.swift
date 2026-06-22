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
    // A throwaway, isolated defaults suite per store so tests never collide.
    let suite = "test.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return RecommendedStepStore(defaults: defaults)
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
        whatINoticed: "I noticed you stop as soon as the build breaks.",
        summary: summary
    )
}

// MARK: - Save behavior + Saved badge (T10: store + badge)

@MainActor
struct SaveBehaviorTests {
    @Test func saveForLaterAddsExactlyOneSavedStep() {
        let store = makeStore()
        #expect(store.savedSteps.isEmpty)

        let model = NextStepModel(
            result: NextStepResult(nextStep: "Write one sentence.", fallbackStep: "Open the file."),
            brainDump: "I'm stuck on the build.",
            store: store
        )
        model.saveForLater()

        // savedSteps drives the Saved-tab badge count.
        #expect(store.savedSteps.count == 1)
        #expect(store.savedSteps.first?.text == "Write one sentence.")
        #expect(store.savedSteps.first?.isSaved == true)
        #expect(model.confirmationMessage == "Saved.")
    }

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

    @Test func stillStuckRevealsFallbackThenSignalsRestart() {
        let m = model(store: makeStore())
        #expect(m.fallbackRevealed == false)

        // First tap reveals the fallback inline...
        #expect(m.registerStillStuck() == true)
        #expect(m.fallbackRevealed == true)

        // ...a later tap signals the caller to restart from the dump.
        #expect(m.registerStillStuck() == false)
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
        let m = ReflectionChoiceModel(extraction: sampleExtraction(), clarification: clarification, nav: AppNavigation())

        #expect(m.options.count == 3)
        #expect(m.optionsFailed == false)
        #expect(m.isBusy == false)
    }

    @Test func initWithNilClarificationFlagsFailureForRetry() {
        // T7: clarification failed but extraction succeeded → screen shows summary + retry.
        let m = ReflectionChoiceModel(extraction: sampleExtraction(), clarification: nil, nav: AppNavigation())
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
        // Stage 2 must produce one option per StuckMode (spec §6). This pins the mode
        // set: adding/removing a case breaks the exhaustive switch below at compile time.
        let modes: [StuckMode] = [.reproduce, .narrow, .clarify]
        for mode in modes {
            switch mode {
            case .reproduce, .narrow, .clarify:
                break  // exhaustive — a new case forces this test to be updated
            }
        }
        #expect(Set(modes.map(\.rawValue)) == ["reproduce", "narrow", "clarify"])
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
