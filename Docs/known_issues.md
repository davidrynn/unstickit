# Known Issues

Status: Open tracking doc
Last updated: 2026-07-13

> Purpose: a running log of observed bugs/quirks that aren't yet fixed, so they don't get
> re-discovered from scratch each session. Not a spec — once an issue is fixed, move its entry
> to "Resolved" (or delete it) rather than leaving it to rot as open.

## Open

### 1. Home screen shows "Unstiku" instead of "Clear Next Step"
**Reported:** 2026-07-13

`INFOPLIST_KEY_CFBundleDisplayName = "Clear Next Step"` is set for both Debug and Release
configs (`Unstickit.xcodeproj/project.pbxproj:411,445`), and `release_readiness_status.md`
recorded this as verified in a built bundle on 2026-07-05. The bundle ID is still
`com.davidrynn.unstiku` (unchanged, expected — kept at release per the ship spec), which is
likely where "Unstiku" is coming from.

Likely cause: a stale install on the device/simulator predating the 2026-07-05 display-name
fix, or the springboard cache holding the old name. iOS sometimes needs a full delete +
reinstall (not just a rebuild) to pick up a changed `CFBundleDisplayName`.

**Next step:** delete the app from the device/simulator, then reinstall a fresh build and
confirm the home screen label. If it still reads "Unstiku" after a clean install, re-open —
that would mean the config fix didn't actually take for the affected build target.

### 2. Generated next steps almost always say "Write one thing…"
**Reported:** 2026-07-13 — **fix implemented 2026-07-14, on-device verification still pending.**

Root cause: `AIService.swift`'s Stage 3 candidate validator (`validationFailure(for:)`, formerly
`validatedStep`) ANDs together five independent gates (empty/length, no newline, ≤35 words, ≤1
sentence, not echoing a forbidden phrase) — the model only needs to trip *one* to get rejected,
and on rejection `generateNextStep` fell straight back to a fixed deterministic template that
starts with "Write" (or "Name") for all three modes, which is what produced the repetitive feel.
Full original analysis is preserved in git history if needed; summary of what changed below.

**Implemented:**
1. **Gate-specific diagnostics.** `validationFailure(for:)` now returns a `StepValidationFailure`
   case (`.empty`, `.tooLong`, `.multiLine`, `.tooManyWords`, `.multiSentence`,
   `.forbiddenPhrase`) instead of a bare `nil`, and the debug log prints which gate fired.
2. **Repair-retry.** `generateActivationStep` no longer falls straight to the template on
   rejection — it sends one targeted follow-up in the same `LanguageModelSession` naming the
   specific violation (e.g. "that was more than one sentence — rewrite as ONE sentence"), mirroring
   Stage 2's `clarify()` repair reroll. Only falls back to the deterministic template if the
   repair attempt also fails validation.
3. **Loosened the forbidden-phrase check.** Replaced the old bidirectional raw substring
   containment (which could false-positive reject a short, legitimate step that merely overlapped
   a few words of a fixed example) with `isNearTotalEcho` — only rejects an exact match or a
   near-total echo (shorter side ≥80% of the longer side's word count).
4. **Added a format-shape hint to the prompt** (`"[Action] the [one specific thing], and stop."`,
   explicitly placeholder-only) so the model has a concrete one-sentence shape to follow, on top
   of the existing prose description.
5. Covered by new `StepValidationTests` in `UnstickitTests.swift` (8 tests — one per gate, plus a
   regression test proving a short legitimate step is no longer false-positive rejected). Full
   `UnstickitTests` target passes.

**Not changed:** the deterministic fallback templates themselves still start with "Write"/"Name"
for all three modes — that's now a secondary safety net rather than the common path, so it wasn't
touched. If on-device testing shows the fallback is still hit often, diversifying those templates
is the next lever.

**Still open:** this can't be exercised end-to-end in the simulator — guided generation throws
there because `SensitiveContentAnalysisML` isn't provisioned (see
`Docs/app_store_assets/README.md`). The fix compiles, and the pure validation logic is unit
tested, but the actual repair-retry behavior against live model output needs a real run on an
Apple-Intelligence-eligible device before this can be marked fully resolved.

### 4. Keyboard obscures the text field on some iPhones
**Reported:** 2026-07-13

Not yet reproduced on a specific device — root cause is a hypothesis based on reading the two
`TextEditor` usages in the app, not a confirmed diagnosis.

- **Brain dump screen** (`BrainDumpView.swift:34-79`) uses a deliberately fixed, non-scrolling
  layout — no outer `ScrollView` — so "the page never shifts and the action button stays pinned
  and visible" (comment at `:35-37`). The hero wordmark + title + subtitle (`:53-71`, ~120pt image
  plus text) are fixed height above the editor, and the "Find my next step" button is pinned via
  `.safeAreaInset(edge: .bottom)` (`:82`). On taller devices there's slack for the keyboard to push
  everything up into; on shorter screens (iPhone SE, mini) the fixed header + editor + pinned
  button may not all fit once the keyboard claims ~300-350pt of height, since there's no scroll
  view to absorb the overflow — only the `TextEditor`'s own internal scroll does, which doesn't
  help the fixed chrome around it.
- **Recent step detail screen** (`RecentStepsView.swift:181-244`, the `addedContext` editor) sits
  in a plain `ScrollView` with no explicit keyboard-avoidance handling beyond SwiftUI's default.
  The editor has `.frame(minHeight: 150)` plus a button below it (`:226-235`) — on a short screen,
  default scroll-into-view behavior may not bring the active line all the way above the keyboard,
  especially right after the editor gains focus.

**Next step:** reproduce on an iPhone SE (3rd gen) or mini-class simulator with the keyboard up on
both screens to confirm which one (or both) is actually affected, then decide the fix — likely
letting the brain dump layout become scrollable (or shrinking the header) below a height
threshold, and/or explicitly scrolling the focused editor into view on the detail screen.

**Note:** User reports that after getting output error, input screen is covered. Try reproducing that way.

## Resolved / not a bug

### 3. Completed sessions don't appear in the "Recent" tab
**Reported:** 2026-07-13 — confirmed as intended current behavior, not a bug.

This is by design per `retain_completed_sessions_spec.md`: tapping **"Got it"** calls
`NextStepModel.completeSession()` → `RecommendedStepStore.complete(id:)`
(`RecommendedStepStore.swift:142-147`), which sets `status = .completed`. The Recent tab
(`RecentStepsView.swift`) only lists `stepStore.activeSteps`, which filters `status == .active`
(`RecommendedStepStore.swift:40-44`) — so completed steps intentionally drop out of view. They
are **not deleted**; they're retained on-device as substrate for a future Pro
archive/pattern-detection feature (see [[pattern-detection-post-mvp]] /
`pattern_detection_spec.md`), which doesn't have a surfaced UI yet.

There is currently no explicit "Save" action anywhere in the flow — `RecommendedStepStore.save()`
exists but nothing in the UI calls it yet, so the store's `isSaved` flag is effectively unused
today. If a "Pro" tier is meant to surface these later, that UI still needs to be built;
tracked as a monetization/roadmap item, not a defect.
