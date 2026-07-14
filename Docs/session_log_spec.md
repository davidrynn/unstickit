# Session Log — Implementation Spec

Status: Draft
Owner: David Rynn
Last updated: 2026-06-29

> **Deferred out of MVP — a trigger-gated post-launch follow-up** (decision 2026-07-02). This is
> the "dumb append-only session log" promised in `unstuck_mvp_spec.md §6` and required by
> `pattern_detection_spec.md` / ADR 0004. It surfaces nothing to users; it silently accrues the
> evidence that gates the entire Pro story. It was previously build-order step 1; it is now the
> **deferred follow-up** in `ship_unstickit_spec.md §Build order` — **do not ship it in 1.0.**

## Why this exists

Two go/no-go questions gate Pro (ADR 0004, `monetization_spec.md`):

1. **Does the core loop retain users?** — answerable from Apple's free analytics + an event SDK.
   **This is the 1.0 gating question, and this log has nothing to do with it.**
2. **Do users get stuck on *recurring* subjects?** — answerable from **nothing Apple provides**.
   It requires our own per-session history. This log is that history.

## Why it's deferred, and when to ship it

The log does **no user-facing good** and produces **no actionable signal now**: recurrence is only
readable once users have *multi-session history*, which needs retention + elapsed time (months
out). So shipping it in the very first build buys only the few weeks between 1.0 and an early
follow-up release — history you couldn't have acted on anyway — while dragging an on-device
retention/privacy disclosure into the launch build.

Question 1 (retention) gates whether we ever care about question 2, and it's answered by analytics,
not this log. So the correct sequence is: ship 1.0 + analytics, watch retention, and ship this log
**the moment retention shows a pulse** (i.e. Pro starts looking worth validating).

**The only real risk of deferring is organizational, not data:** that it's forgotten and we again
start from zero history when we finally want it. Mitigation: track it against the retention
trigger, not a vague "when we build Pro." History cannot be back-filled, so it must ship *before*
Pro validation begins — just not in 1.0.

## Scope: deliberately dumb

Write a handful of fields on each resolved session. **No** `repeatSubjectKey`, **no** `threadID`,
**no** aggregation, **no** surfaces, **no** paywall, **no** outcome analytics. Those belong to the
post-MVP engine in `pattern_detection_spec.md` — do not build them here. Outcome/funnel telemetry
(save / defer / still-stuck / bail) is an analytics-event concern (step 2 of the ship spec), **not**
a field of this local log.

## Prerequisite: make the enums `Codable`

`StuckMode` and `BlockerType` in `Unstickit/AI/AITypes.swift` are `@Generable enum … : String`
today but are **not** `Codable`. The log can't encode without it. Add `Codable` conformance:

```swift
@Generable
enum BlockerType: String, Codable { … }   // add Codable

@Generable
enum StuckMode: String, Codable { … }      // add Codable
```

Both are already `String`-backed raw-value enums, so conformance is synthesized — no custom coding.
This is the only change to existing AI types.

## Data model

```swift
struct SessionLogEntry: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let brainDumpSnippet: String   // short, truncated — see privacy note
    let chosenMode: StuckMode
    let blockerTypes: [BlockerType]
}
```

- `id` / `createdAt` — identity and ordering.
- `brainDumpSnippet` — a **truncated** snippet of the original dump, mirroring
  `RecommendedStep.issueSummary` (collapse whitespace, cap ~84 chars, ellipsize). This is the only
  free-text field and it never leaves the device (ADR 0001). It exists so the future recurrence
  engine has a human-readable subject to key on; it is not analytics payload.
- `chosenMode` — the `StuckMode` the user tapped on S2 (Reflection + Choice).
- `blockerTypes` — the `BlockerType`s from the Stage 1 `ExtractionResult.blockers`.

## Open decision: user-facing "Clear history" control

The disclosure obligation (see `app_store_release_assets_spec.md §7`) is satisfied by a one-line
privacy-policy statement — a consent modal is **not** warranted for a purely on-device behavior.
But because the log retains a truncated snippet of the user's own words, the highest-trust move is
to let them delete it. This is optional for 1.0 and is the user's call:

- **Ship a quiet "Clear history" control** (recommended if cheap): a single row in a Settings/About
  surface that calls a new `SessionLogStore.clear()` and empties the array. This **relaxes the
  append-only rule below** — the store stays append-only for *writes*, but gains one user-initiated
  bulk-delete. If shipped, the privacy policy may promise it (§7); if not, the policy must not.
- **Defer it:** keep the log strictly append-only with no delete, and omit the "clear it any time"
  sentence from the privacy policy. Disclosure still holds via the retention statement alone.

Either way, do **not** add per-entry editing or automatic purging — only an all-or-nothing clear.
The recurrence engine (`pattern_detection_spec.md`) must tolerate a user having cleared history
(treat it as "no prior sessions," never an error).

## Storage: `SessionLogStore`

Match the existing convention (`RecommendedStepStore`, `ProInterestStore`): a `@MainActor final
class … : ObservableObject`, JSON-`Codable` array persisted in `UserDefaults`.

```swift
@MainActor
final class SessionLogStore: ObservableObject {
    @Published private(set) var entries: [SessionLogEntry] = []

    private let defaults: UserDefaults
    private let storageKey = "session_log"

    init(defaults: UserDefaults = .standard) { … load() … }

    /// Append-only. Called once per resolved session.
    func record(brainDump: String, chosenMode: StuckMode, blockerTypes: [BlockerType])
}
```

- **Append-only for writes.** No per-entry edit, no automatic purge (unlike `RecommendedStepStore`,
  which expires deferred items). The log is a permanent local history — the one allowed exception is
  a user-initiated bulk `clear()`, *if* the "Clear history" control ships (see open decision above).
- Inject `UserDefaults` for testability, as the other stores do.
- `record(...)` builds the truncated snippet internally so callers pass the raw dump.

## When to write — the "resolved" definition

Append **exactly once**, at the moment a next step is successfully produced and presented to the
user on S4 (the `NextStepResult` is shown). That is the cleanest "this session produced a result"
signal and the unit the recurrence engine reasons about.

- Write on **reaching S4 with a generated step**, not on "Start" — accepting the step is an
  outcome concern, not part of the dumb log.
- Do **not** write for sessions that never produce a step (abandoned on S1, clarification loops,
  ineligible device).
- An in-session "I'm still stuck" retry that regenerates a step in the *same* session must **not**
  double-log. One resolved session → one entry. (The future engine excludes in-session retries via
  `threadID`; here we simply guard against writing twice for one flow.)

## Wiring

The resolve point lives in the flow that produces the next step — `NextStepModel` /
`generateNextStep`. Inject `SessionLogStore` the same way other stores are provided (app-level
owner, comparable to how `RootTabView` owns app state). At the resolve point, call
`record(brainDump:chosenMode:blockerTypes:)` with the original dump, the tapped `StuckMode`, and the
`ExtractionResult.blockers.map(\.type)`.

## Acceptance criteria

- [ ] `StuckMode` and `BlockerType` conform to `Codable`.
- [ ] `SessionLogEntry` exists with the five fields above.
- [ ] `SessionLogStore` persists an append-only array to `UserDefaults` and reloads on launch.
- [ ] Exactly one entry is appended when a session reaches S4 with a generated step.
- [ ] No entry is written for abandoned/ineligible/clarification-only sessions.
- [ ] An in-session "I'm still stuck" regeneration does not produce a second entry.
- [ ] `brainDumpSnippet` is truncated; no raw full dump and no reflected/next-step text is stored.
- [ ] Nothing in the log is surfaced in the UI (no list, no badge, no count shown to the user).

## Out of scope (defer to `pattern_detection_spec.md`)

`repeatSubjectKey`, `threadID` propagation, the trailing-window aggregator, the ≥3-session /
≥2-thread repeat rule, synthesis, any surface, and `isPro` gating. None of it here.

## References

- `unstuck_mvp_spec.md §6` — the source requirement (the dumb log).
- `pattern_detection_spec.md` — the post-MVP engine this log feeds.
- ADR 0004 — defer pattern detection until recurrence is validated.
- ADR 0001 — on-device privacy boundary (the snippet never leaves the phone).
- `ship_unstickit_spec.md §Build order` — this is the deferred, trigger-gated follow-up (not 1.0).
