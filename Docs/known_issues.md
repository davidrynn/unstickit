# Known Issues

Status: Open tracking doc
Last updated: 2026-07-15

> Simulator-testing note: after long UI-automation sessions on one booted simulator (repeated
> ⌘⇧K keyboard toggles, HID typing), the sim's text-input/responder system can degrade — taps
> stop granting editor focus app-wide even after app relaunch. Before diagnosing focus bugs in
> app code, shut down and re-boot the simulator; the 2026-07-15 "refocus wedge recurrence" was
> exactly this and reproduced cleanly as *working* after a fresh boot.

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

**Follow-up (2026-07-15): Stage 3 redesigned around "first real move," constraints loosened.**
On-device testing showed the repair-retry fix wasn't enough: even successful generations were
meta-work about the tasks ("write down the top three tasks… categorize them") rather than a
first move *on* a task, and the fallback template still surfaced. Root cause was the prompt
itself — ~40 lines of rules/NEVER-lists (which small on-device models follow poorly, and which
that output visibly violated) plus an "intentionally incomplete, 2-minute, one-sentence" framing
that steered generation away from the actual task. Changes (see `AI_PROMPT_GUIDELINES.md`, Core
Principle revision note):
1. Prompt rewritten to ~1/3 the length around one target shape: the first real, concrete move on
   the user's actual task ("Open the permit application and gather the first document it asks
   for"), with mode guidance rewritten to point at the task rather than at reflection.
2. Validation loosened to match: up to two sentences (was one), ≤45-word slack against a ≤30-word
   ask (was 35/25), 280 chars (was 240). Forbidden-phrase list trimmed to the one remaining
   prompt example plus two known canned outputs; the old prompt's deleted examples were removed.
3. `ActivationStep` `@Guide` shortened accordingly (it costs context tokens on every call).
Repair-retry, gate diagnostics, and deterministic fallbacks are unchanged. Same simulator
verification limits as above — needs an on-device run to confirm step quality.

### 4. Keyboard obscures the text field on some iPhones
**Reported:** 2026-07-13 — **reproduced 2026-07-14 on an iPhone SE (3rd gen) / iOS 26.5 simulator;
brain dump screen fixed and verified same day. Still open only for the `RecentStepsView` editor
(unverified).**

**Fix (2026-07-14, `BrainDumpView.swift`):**
1. The hero wordmark, subtitle, and deferred-return card collapse while the editor is focused
   (title stays as the anchor), animated on `isEditorFocused`. On the SE this takes the editor
   from a ~10pt sliver to ~150pt with the keyboard up; on tall phones it just adds writing room.
2. `submit()` resigns editor focus before the loader goes up, so an error always returns to the
   full keyboard-free layout with the dump, the error line, and the button all visible.
3. Transition polish (2026-07-15, follow-up on user feedback): the collapse is keyed on
   `isCompact = isEditorFocused || isLoading`, so the chrome stays collapsed through the
   loading phase — submit resigns focus and raises the loader in the same transaction, and the
   hero no longer re-expands underneath the dim. Loader/dim fades slowed 0.14s → 0.35s
   (matched across `BrainDumpView`, `RootTabView`, `ReflectionChoiceView`), layout
   collapse/expand 0.25s.
   Second round (same day): the outgoing and incoming screens were both visible during the
   handoff. Two causes: `FullScreenPauseLoaderOverlay` was `.thinMaterial` (translucent — the
   screens cross-faded through it; now opaque `Color(.systemBackground)`), and destinations
   cleared `loadingMessage` in `.onAppear`, which fires when a push *starts* — if the system
   animates the push despite `pushBehindLoader`'s disabled transaction, the loader faded during
   the slide. Destinations now call `nav.dismissLoaderAfterPushSettles()` (clears after 450ms),
   so the loader always reveals a stationary screen; `NextStepView.revealStep` flourish retimed
   0.2s → 0.95s to fire after the reveal, not behind the curtain. Verified frame-by-frame from
   a simulator recording: reveal shows only the settled destination.
   Testing aid: `UI_MOCK_AI=1` (DEBUG env hook in `AIService`, alongside
   `UI_FORCE_EXTRACT_ERROR`) returns canned Stage 1–3 results after a 1.5s delay so the full
   dump → reflection → next-step flow runs on simulators without Apple Intelligence.
4. Removed `.disabled(isLoading)` from the screen content (the full-screen loader overlay already
   blocks touches, and `submit()` has a reentry guard; the button keeps its own `disabled`).
   This was load-bearing: disabling the focused `TextEditor` in the same transaction as the
   programmatic focus resign desynced `@FocusState` from the first responder and permanently
   wedged the editor — after an error it could never be refocused (taps landed, no keyboard, no
   cursor). Do not reintroduce a whole-screen `.disabled` here.

Verified on the SE simulator: typing state, submit → forced error → return, and refocus-to-retry
all render correctly; iPhone 17 spot-checked for regressions.

**Confirmed on the brain dump screen.** With the software keyboard up on the SE (667pt tall), the
fixed chrome (120pt wordmark + title + subtitle above, pinned button + keyboard toolbar below)
consumes nearly the whole screen and the `TextEditor` collapses to a ~10pt sliver — the user's
typed text is completely invisible. This happens **while typing**, before any error.

The reported "after getting output error, input screen is covered" variant reproduces the same
way and is slightly worse: submit does not resign editor focus, so the keyboard stays up through
the loader; when the error returns, the red error line joins the bottom `safeAreaInset` and
squeezes the collapsed editor further. The user lands on an error telling them to "try again"
while unable to see what they wrote. Tapping the keyboard-toolbar **Done** fully restores the
layout — the bug is strictly the keyboard-up state on short screens.

Repro (simulator): create an SE 3rd-gen sim on an iOS 26 runtime (`xcrun simctl create "SE test"
"iPhone SE (3rd generation)" com.apple.CoreSimulator.SimRuntime.iOS-26-5`), launch with
`SIMCTL_CHILD_UI_BYPASS_AI_GATE=1 SIMCTL_CHILD_UI_FORCE_EXTRACT_ERROR=1` (the second is a
DEBUG-only hook added 2026-07-14 in `AIService.extract` that throws `extractionFailed` after a
1.5s delay, mirroring `UI_BYPASS_AI_GATE`), focus the editor with the software keyboard visible,
type ≥4 words, tap "Find my next step."

The `RecentStepsView` `addedContext` editor variant is still unverified.

Original analysis (hypothesis now confirmed for the brain dump screen):

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

**Next step:** check the `RecentStepsView` `addedContext` editor on the same SE simulator (needs
an active recent step, so it requires either a device with Apple Intelligence or seeding the
store); apply the same treatment if it's affected.

### 5. Stage 1 invents blockers; Stage 2 options parrot the prompt
**Reported:** 2026-07-15 (real device session) — **fix implemented same day, on-device
verification pending.**

Observed session: input said "just released it… the name is wrong… the product isn't good…
I don't know what to do." Stage 1 fabricated a practical blocker ("there are bugs in the app")
and dropped the one concrete fact (the wrong name); Stage 2 returned three near-verbatim copies
of its own prompt text ("I keep trying fixes but nothing works" — the prompt's example — plus
first-person recastings of the `narrow`/`clarify` mode descriptions). The cascade fed Stage 3 a
false premise ("check the error messages") even though the Stage 3 generation itself was
well-shaped.

Root causes: (a) Stage 1's blocker instruction listed three types, which the small model treats
as slots to fill — it padded with an invented "bugs" blocker; (b) Stage 2 never saw the user's
own words (only the already-abstracted extraction) and had a copyable example + mode
descriptions sitting in its prompt with no echo defense.

**Implemented (`AIService.swift`):**
1. Stage 1 blockers rule rewritten: fewer is better, one is fine, never invent a blocker to fill
   the list or cover a missing type.
2. Stage 2 prompt rewritten to include the brain dump verbatim and require every label to
   mention something from the user's own words; the example is domain-shifted (grant
   application) and explicitly marked do-not-reuse.
3. New `isGenericOptionLabel` guard: coverage-based echo detection (≥80% of a label's words
   appearing in a known prompt phrase) against the example and first-person recastings of the
   mode descriptions. Echoed labels are treated like missing modes — they trigger the existing
   reroll — but are kept as a last resort in the best-effort path rather than dropping a row.
   Covered by `GenericOptionLabelTests` using the observed session's three labels as fixtures.
4. `clarify()` now takes `brainDump:`; call sites updated (`BrainDumpView`, `RecentStepsView`,
   `ReflectionChoiceModel` ×2).

**Still open:** same simulator limitation as #2 — needs an on-device rerun of the same brain
dump to confirm grounded options and no invented blockers. Deeper product question flagged, not
addressed: all three StuckModes assume mid-work stuckness; post-release disappointment ("shipped
it, unhappy with it") doesn't map cleanly to any mode.

**POC (2026-07-15, second session): blocker-as-options.** A rerun with the fixes still produced
no grounded Stage 2 set (4 attempts across 2 sessions, 0 good sets — the guard caught two echoes
including an example-swap, but a synonym-swap echo slipped under the 80% threshold and the
best-effort path shipped it). Meanwhile Stage 1's blockers *were* the grounded "how I'm stuck"
statements. POC now in place (committed on top of `8b70b51`, revert to that to compare):
- The tappable options ARE the Stage 1 blockers, recast to first person
  (`ClarificationResult.derived(from:)` / `firstPersonLabel(from:)` in `AITypes.swift`); Stage 3
  guidance picked via `BlockerType.impliedMode` (practical/informational → narrow, emotional →
  clarify; reproduce unreachable from derived options).
- The generated-options model call remains behind **"Something else"**, as the retry path, and
  as the fallback when extraction returns no blockers.
- Also fixed: `isActionable=false` with a missing/empty `clarificationPrompt` was a silent no-op
  on the dump screen (observed this session — first extraction returned false with everything
  *except* the prompt filled, and the tap appeared to do nothing, prompting a resubmit); now
  falls back to a default question. Stage 1 debug print now includes `clarificationPrompt`.
- Covered by `BlockerDerivedOptionsTests`.
To evaluate on device: same brain dump; expect options like "I am very disappointed with the
app's performance / I don't know what to do next / The name of the app is incorrect," and after
tapping the name option, a Stage 3 step about the name specifically.

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
