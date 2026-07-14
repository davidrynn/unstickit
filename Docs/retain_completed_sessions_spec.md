# Retain Completed Sessions — Spec / Task

Status: Implemented (2026-07-08)
Owner: David Rynn
Last updated: 2026-07-08

> **Goal:** stop discarding a session's record when the user *completes* it. Today, tapping
> **"Got it"** hard-deletes the record — success erases the work. This task retains completed
> sessions as a private, on-device record so a future Pro archive / pattern-detection feature
> has substrate to work with. It is the "Retention precondition" called out in
> `monetization_spec.md`.
>
> **This task does NOT surface an archive, add a paywall, or change the flow.** It only stops
> deleting completed work. Scope is deliberately narrow.

## Why (one line)

Per `monetization_spec.md` ("monetize accumulation and depth, never cadence"), the private
archive is the near-term Pro anchor — but there is nothing to monetize because the binary
currently destroys the asset on completion. This is the purpose-safe, pricing-independent
prerequisite: preserve the data now, decide the paywall later.

## Current behavior (ground truth)

- A `RecommendedStep` is silently recorded as an open loop (`isSaved: false`, `status: .active`)
  when the Next Step screen appears — `NextStepView.swift:108` → `NextStepModel.recordSession()`
  (`NextStepModel.swift:42-49`) → `RecommendedStepStore.recordSession(...)`
  (`RecommendedStepStore.swift:102-127`).
- **Both** "Got it" (`finish()`, `NextStepView.swift:130`) and "Delete & start over"
  (`startOver()`, `NextStepView.swift:135`) call `resolveAndReset()` (`:139-143`) →
  `NextStepModel.resolveSession()` (`:54-57`) → `RecommendedStepStore.delete(id:)`
  (`RecommendedStepStore.swift:130-134`), a **hard delete**. Completion and discard are
  currently indistinguishable.
- The Recent tab (`RecentStepsView.swift`) shows `activeSteps` (status `.active`), so it lists
  only open loops and empties as sessions resolve.
- The only thing that survives resolution today is the invisible, evidence-only
  `SessionLogEntry` (84-char snippet + metadata), which is not a usable archive.
- Note: `RecommendedStepStatus` already defines an unused `.dismissed` case
  (`RecommendedStep.swift:9-12`) — the model was built anticipating non-deletion states but
  never used them.

## The change

**Split resolution into "completed" (retain) vs "discarded" (delete).**

1. **Data model** (`RecommendedStep.swift`):
   - Add a `.completed` case to `RecommendedStepStatus`.
   - Add `var completedAt: Date?` to `RecommendedStep` (optional → old stored records decode to
     `nil`; additive-safe with synthesized `Codable`).

2. **Store** (`RecommendedStepStore.swift`):
   - Add `func complete(id: UUID)` that sets the matching record's `status = .completed` and
     `completedAt = Date()` **instead of removing it**. Keep `delete(id:)` unchanged for discards.
   - `activeSteps` (`:40-44`) is unchanged — it filters `status == .active`, so `.completed`
     records automatically drop out of the Recent tab. No Recent-tab changes needed.
   - Verify `purgeExpired()` (`:176-193`) never purges `.completed` records. (It shouldn't today:
     completed records have `expiresAt == nil` and `status != .active`, so both filters keep them —
     **add a test to lock this in.**)

3. **View model** (`NextStepModel.swift`):
   - Replace `resolveSession()` with two methods: `completeSession()` → `store.complete(id:)`, and
     `discardSession()` → `store.delete(id:)`. Both clear `recordedID`.

4. **View** (`NextStepView.swift`):
   - `finish()` ("Got it") → `completeSession()`.
   - `startOver()` ("Delete & start over") → `discardSession()`.
   - **Defer path caveat:** the come-back-tomorrow sheet dismisses to `finish` today
     (`.sheet(isPresented: $model.deferConfirmationShown, onDismiss: finish)`, `:113`). After the
     split, the defer path must **discard** the open-loop record (the separate deferred record
     created by `deferUntilTomorrow` supersedes it) — point that `onDismiss` at the discard reset,
     **not** `completeSession()`, or you'll retain a duplicate of a step that was actually deferred.

## Out of scope (explicitly deferred)

- Any UI to browse / search / surface the retained archive — that is the later **Pro** feature.
- Any paywall, IAP, or pricing.
- Project / thread grouping (`StepThread`) — separate, unimplemented spec.
- "Let go" in the Recent tab (`RecentStepsView` → `dismiss`) stays a hard delete — it is an
  intentional user removal, not a completion.
- Changing what the Recent tab displays (stays open-loops only).

## Tests

- "Got it" retains a record with `status == .completed` and a non-nil `completedAt` (not deleted).
- "Delete & start over" still removes the record entirely.
- `completedAt` and `.completed` decode correctly from JSON that predates them (nil / round-trip).
- `.completed` records survive `purgeExpired()` and are not counted against the 20-record
  open-loop cap.
- `activeSteps` (and therefore the Recent tab) excludes `.completed` records.
- Defer path: dismissing the come-back-tomorrow sheet leaves the deferred record and does **not**
  create a `.completed` duplicate of the open-loop record.

## Risks / considerations

- **Unbounded growth in `UserDefaults`.** The completed archive never purges, and each record can
  hold a full brain-dump string. Episodic use makes growth slow, so this is fine for now, but
  `UserDefaults` is not ideal for a growing dataset. When the archive UI ships, plan to either cap
  the retained set (generous, e.g. keep the most recent N hundred) or migrate persistence to
  SwiftData / a JSON file. **Flag, not a blocker for this task.**
- **Privacy label unaffected.** Retained records stay on-device in `UserDefaults`; nothing is
  transmitted. The "Data Not Collected" label and privacy policy are unchanged.

## Done when

- Completing a session ("Got it") leaves a persisted `.completed` record on device; discarding
  ("Delete & start over") and "Let go" still delete.
- Recent tab behavior is visibly unchanged (still open-loops only).
- The tests above pass, including the old-data decode and the defer-path case.

## References

- `monetization_spec.md` — "Retention precondition" (this task is its implementation).
- `pattern_detection_spec.md` / `session_log_spec.md` — the eventual consumers of the retained
  data (later Pro feature).
- `come_back_tomorrow_spec.md` — the defer flow the caveat above protects.
