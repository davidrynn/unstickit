# Unstickit — Flow Redesign Spec

## Status
**Draft** — proposed replacement for the current Reflection + Clarification flow

**Date:** 2026-06-15

---

## 0. Naming

**Unstickit** is the Xcode project / repository name. **Unstick** is the user-facing product
name shown in-app and in all copy. Both are intentional; do not "fix" one to match the other.

## 1. Product Intent

The core Unstickit moment is:

> The user dumps the mess, and the app turns it into one doable next step.

The brain dump is already useful because it lets the user externalize what feels tangled.
The app should then add value by reflecting just enough to build trust, asking one focused
choice, and producing a small action that is easier to start than avoid.

This redesign should make the app feel less like it is asking the user to review an AI report
and more like it is calmly helping them move.

---

## 2. Problem With Current Flow

The current post-dump validation screen is helpful but too dense.

It currently shows several overlapping interpretations:

- **Your goal**
- **What might be blocking you**
- **What might be making this hard**
- **Something I noticed**
- **Does this sound right?**

These are individually valuable, but together they create a scrollable review task. That is
especially costly for users who are already overwhelmed, avoidant, or unsure where to start.

The redesign should preserve validation while removing the report-like feeling.

---

## 3. Recommended New Flow

### High-Level Flow

1. **Brain Dump**
2. **Loading**
3. **Reflection + Choice**
4. **Loading**
5. **One Next Step**

This replaces the current separate Reflection and Clarification screens with one combined
screen.

### Flow Principle

Validation should fit on one screen.

If the user has to scroll to validate what the AI understood, the AI said too much.

---

## 4. Navigation Structure

### Primary Navigation

Use a bottom tab bar instead of a large **Recent steps** tile on the brain dump screen.

Recommended tabs:

- **Unstick**
- **Saved**

The **Unstick** tab is the primary flow. The **Saved** tab contains intentionally saved steps
only (see §13). Recent-but-unsaved steps are out of scope for MVP.

### Why Move Recent Steps To A Tab

The current **Recent steps** tile competes with the primary job of the first screen. The user
came to dump what they are stuck on, but the first large interactive object is navigation to
past steps.

A bottom tab bar keeps saved steps accessible without making them part of the active getting
unstuck flow.

### Saved Tab Behavior

- Show a badge count on **Saved** when intentionally saved steps exist.
- Empty state: **No saved steps**
- Body: **Steps you keep for later will show up here.**
- Existing `RecentStepsView` can become the content of the **Saved** tab.

---

## 5. Screen Specs

### S1 — Brain Dump

**Purpose:** Give the user a low-pressure place to dump what is tangled.

**Content:**

- Logo/title: **Unstick**
- Prompt: **What are you stuck on?**
- Helper copy: **Write whatever comes to mind**
- Large multiline text input
- Character count, if useful: `174/500`
- Primary CTA: **Find my next step**

**Remove:**

- The large **Recent steps** tile

**States:**

- **Empty** — CTA disabled
- **Has input** — CTA enabled
- **Loading** — full-screen loading overlay
- **Needs clarification** — show one inline question below the input
- **Error** — show concise error below the input

**Loading copy:**

**Working on your reflection...**

**Transition:**

Tap **Find my next step**:

- Run extraction
- Run clarification option generation
- Navigate to **S2 — Reflection + Choice** when both are ready

If latency becomes too long, keep the existing loading screen rather than showing partial
reflection content.

---

### S2 — Reflection + Choice

**Purpose:** Reflect the user's situation briefly, then ask the choice that drives the next
step.

**Title:**

**Here’s what I’m hearing**

**Summary card:**

Label:

**SUMMARY**

Body:

One short paragraph, ideally 1-2 sentences.

Example:

> You want to finish your app, but AI/SwiftUI bugs keep making the next step feel unclear.

**Choice section:**

Label:

**WHICH FEELS MOST TRUE RIGHT NOW?**

Options:

- 3 AI-generated first-person choices, one for each `StuckMode`
- A fourth static option: **Something else**

Example options:

- **I keep trying fixes, but nothing works.**
- **I’m not sure where to begin or what the real cause is.**
- **I feel overwhelmed and can’t focus.**
- **Something else**

**Correction action:**

Use one low-emphasis link:

**Edit what I wrote**

This returns the user to the brain dump with their original text preserved, ready to revise.
Avoid **Edit the summary** — the summary is AI-generated, not user text, so that label promises
inline summary editing the action does not perform. Avoid **Start over** (implies the text is
lost) and **Try again** (on a choice screen it reads as "reroll the options," not "edit my
text"). Do not also show **That’s not quite it**; it overlaps with **Something else** and
creates an unclear distinction.

**Behavior:**

- Tapping one of the 3 generated options runs next-step generation using that option’s
  `StuckMode`.
- Tapping **Something else** regenerates a fresh set of 3 options from the same brain dump,
  with a brief loading state. It does **not** open a text field. This preserves the core
  no-typing principle (see MVP spec §3 rationale): typing is exactly the cognitive load a
  stuck user lacks, and a free-text answer has no `StuckMode`, which Stage 3 generation
  requires. Because rerolling adds no new user signal, the second set can miss for the same
  reason the first did; after one reroll, nudge toward **Edit what I wrote**.
- Tapping **Edit what I wrote** returns to the brain dump with the existing text preserved.

**Important constraint:**

This screen should aim to fit one iPhone viewport without scrolling for ordinary output at the
default Dynamic Type size. It is a design target, not a hard rule: when the summary or options
wrap, or the user has enlarged text, the screen must scroll gracefully rather than truncate or
clip the **Something else** row. Never sacrifice AI output or a tappable control to avoid a
scroll.

---

### S3 — One Next Step

**Purpose:** Give the user one small, concrete action.

**Title:**

**Here’s your next step**

**Content:**

Label:

**YOUR NEXT STEP**

Prominent step text:

> Write one sentence:
> “I keep getting stuck with AI/SwiftUI compatibility because...”
> Then stop.

Helper copy:

**Keep it short. This is only to surface the real friction, not solve the whole app.**

Primary CTA:

**Start this step**

Secondary actions:

- **I’m still stuck**
- **Save for later**
- **Come back tomorrow** only if the deferred flow exists and is implemented (see
  `come_back_tomorrow_spec.md` — a soft return point, not a "pause," with an optional reminder)

**Behavior:**

- **Start this step** clears the active draft and returns to the Unstick tab.
- **I’m still stuck** reveals the existing `fallbackStep` inline (per §13); it does not return
  to the choice screen.
- **Save for later** stores the step locally and updates the Saved tab badge.
- **Come back tomorrow** defers the step per `come_back_tomorrow_spec.md` (creates one
  `RecommendedStep` with `source == .deferredTomorrow`, clears the draft, optionally offers a
  reminder).

---

## 6. AI Contract Changes

### Stage 1 — Extraction

Keep the existing `ExtractionResult`, but the UI should no longer display every field.

Displayed on S2:

- `goalSummary` and/or `frictionSummary` folded into a single concise `summary`

Not displayed by default:

- individual blockers
- blocker type badges
- `whatINoticed`

These fields may still be useful internally for generating better clarification options and
next steps.

### New Display Summary

**Preferred: add one field to the existing extraction call** so no extra round-trip is
introduced:

```swift
@Generable
struct ExtractionResult {
    let isActionable: Bool
    let clarificationPrompt: String?
    let goalSummary: String
    let blockers: [Blocker]
    let frictionSummary: String
    let summary: String          // NEW — second-person display line for S2
}
```

A separate `ReflectionSummary` generation is a second model call on the flow’s critical path
and adds latency to the moment we most want to feel instant. Only fall back to a standalone
call if folding `summary` into extraction measurably degrades extraction quality.

Avoid local concatenation of `goalSummary` + `frictionSummary` for display — it reads stitched
and breaks the second-person voice.

Prompt guidance:

- Write in second person.
- Use one short paragraph.
- Maximum 28 words.
- Name the user’s goal and the friction.
- Avoid diagnosis, therapy language, and generic encouragement.

Example:

> You want to finish your app, but AI/SwiftUI bugs keep making the next step feel unclear.

### Stage 2 — Clarification Options

Keep the existing `ClarificationResult` shape:

```swift
struct ClarificationResult {
    var options: [ClarificationOption]
}
```

Requirements:

- Exactly 3 generated options
- One option per `StuckMode`
- First-person language
- Short enough to fit in a tappable row
- Specific to the user’s brain dump

### Stage 3 — Next Step

Continue generating one activation step based on:

- original brain dump
- extraction result
- selected clarification option
- selected `StuckMode`

The next step should remain small, concrete, and intentionally incomplete.

---

## 7. Data And State Changes

### Navigation

Current destinations:

```swift
case reflection(ExtractionResult, brainDump: String)
case clarification(extraction: ExtractionResult, clarification: ClarificationResult, brainDump: String)
case nextStep(NextStepResult, brainDump: String)
```

Recommended replacement:

```swift
case reflectionChoice(
    extraction: ExtractionResult,
    clarification: ClarificationResult,
    brainDump: String
)
case nextStep(NextStepResult, brainDump: String)
```

The old separate reflection screen can be removed once the combined screen is stable.

### Tab Root

Use a root `TabView`:

- **Unstick** tab: current primary `NavigationStack`
- **Saved** tab: `RecentStepsView` or a renamed saved/recent steps view

The saved tab should use a badge when `RecommendedStepStore` has active steps.

### View-model ownership (avoid re-analysis on tab return)

With the tab shell (T1), the **Unstick** tab's `NavigationStack` and its pushed screens stay
alive when the user switches to **Saved** and back. On return, SwiftUI re-fires `.onAppear`.

The original `ReflectionView` started its clarification call in `.onAppear { loadClarification() }`,
so returning to the tab re-ran the AI analysis even though the result was already held in
`@State` (the state survives the tab switch — only `.onAppear` re-fires, and it re-launches the
call unconditionally).

**Rule for the new screens: own AI generation in a `@StateObject` view model and start each
call exactly once — never from `.onAppear`.** Concretely:

- Kick the task off from an idempotent `load()` (no-op if a result already exists or a call is
  in flight), or use SwiftUI `.task(id:)` keyed to the brain dump so it runs once per input.
- Preferred: per **T5**, run extraction + clarification-option generation *before* navigating
  (behind the dump loader), so the combined screen receives finished data and starts no work on
  appear — there is nothing to re-trigger.

The old `ReflectionView` / `ClarificationView` are **not patched** for this; they are removed in
**T11**. A one-line idempotency guard would stop the reload there, but it is not worth adding to
soon-deleted code.

---

## 8. Copy System

Preferred copy:

- **What are you stuck on?**
- **Write whatever comes to mind**
- **Find my next step**
- **Working on your reflection...**
- **Here’s what I’m hearing**
- **Which feels most true right now?**
- **Something else**
- **Edit what I wrote**
- **Here’s your next step**
- **Start this step**
- **I’m still stuck**
- **Save for later**

Avoid:

- **Next** as the main CTA on the brain dump screen
- report-like section stacks
- therapy-like labels
- productivity/task language
- asking the user to validate more than one screen of AI output

---

## 9. Visual Direction

The interface should feel calm and direct, not decorative.

Recommended style:

- White or near-white background
- Large readable text
- One prominent blue CTA per screen
- Cards/rows only where they organize action
- No nested cards
- Minimal shadows
- Bottom tab bar for persistent navigation

The design should make the product’s main promise obvious:

> Dump what is tangled. Get one next step.

---

## 10. Mockups

Reference mockups:

- `DesignMockups/flow-composite.svg`
- `DesignMockups/flow-1-brain-dump.svg`
- `DesignMockups/flow-2-hearing-choice.svg`
- `DesignMockups/flow-3-next-step.svg`

These are design references, not implementation assets.

---

## 11. Acceptance Criteria

### Flow

- A user can enter a brain dump and tap **Find my next step**.
- The app shows the existing full-screen loading treatment.
- The app navigates to a combined reflection/choice screen.
- The combined screen fits one viewport for normal outputs at default type size, and scrolls
  gracefully (without clipping any control) when content wraps or Dynamic Type is enlarged.
- The user can select one of three generated choices.
- If clarification generation fails but extraction succeeds, the screen still shows the summary
  and offers retry plus **Edit what I wrote**, rather than dead-ending on the loader.
- The app generates and displays one next step.
- The user can save the step and find it in the Saved tab.

### Navigation

- The brain dump screen no longer shows the large **Recent steps** tile.
- A bottom tab bar exposes **Unstick** and **Saved**.
- The Saved tab shows a badge/count when saved or recent steps exist.

### Copy

- The brain dump CTA says **Find my next step**.
- The reflection title says **Here’s what I’m hearing**.
- The next step CTA says **Start this step**.
- No screen asks the user to read a long AI report before continuing.

### AI Output

- Summary is concise enough to fit in the summary card.
- Clarification choices are first-person, specific, and short.
- The next step is one small action, not a plan.

---

## 12. Implementation Tickets

Each ticket is a self-contained, review-gated unit of work. Build them in order; **stop after
each and review against its "Done when" gate before starting the next.** A ticket is only
complete when every box in its gate is checked. Tickets are sized so a single review pass is
meaningful — if one balloons, split it rather than merging the review.

Status legend: `[ ]` not started · `[~]` in progress · `[x]` done & reviewed.

---

### T1 — Tab shell (Unstick / Saved)
**Status:** `[x]`  ·  **Depends on:** none

**Goal:** Introduce the root `TabView` so navigation is in place before screens change.

**Scope:**
- Add a root `TabView` with two tabs: **Unstick** (the existing primary `NavigationStack`) and
  **Saved**.
- Move `RecentStepsView` to be the content of the **Saved** tab (no behavior change yet).
- Add a badge on **Saved** driven by `RecommendedStepStore` (saved steps only, per §13).
- Empty state for Saved: title **No saved steps**, body **Steps you keep for later will show
  up here.**

**Files:** `ContentView.swift`, `RecentStepsView.swift`, the recommended-steps store.

**Done when:**
- [x] App launches into the **Unstick** tab with the existing flow intact.
- [x] **Saved** tab shows `RecentStepsView` content (or the empty state).
- [x] Saved badge appears only when at least one intentionally-saved step exists.
- [x] No regression in the existing dump → next-step flow.

---

### T2 — Brain Dump screen update
**Status:** `[x]`  ·  **Depends on:** T1

**Goal:** Make S1 match the redesign and `flow-1-brain-dump.svg`.

**Scope:**
- Remove the large **Recent steps** tile.
- Title **Unstick**; prompt **What are you stuck on?**; helper **Write whatever comes to mind**
- CTA **Find my next step** (replaces the old CTA). Disabled when input is empty.
- Keep draft autosave/restore behavior from the MVP spec.

**Files:** `BrainDumpView.swift`.

**Done when:**
- [ ] Screen matches `flow-1-brain-dump.svg` (no tile, correct copy, tab bar visible).
- [ ] CTA is disabled on empty input, enabled with text.
- [ ] Draft still survives app kill/relaunch.

---

### T3 — Extraction summary field (AI contract)
**Status:** `[x]`  ·  **Depends on:** none (can run parallel to T1–T2)

**Goal:** Produce the concise S2 display line without an extra model round-trip.

**Scope:**
- Add `summary: String` to the existing `ExtractionResult` `@Generable` struct (§6).
- Update the extraction prompt: second person, one short paragraph, ≤28 words, names the goal
  and the friction, no diagnosis/therapy/encouragement.
- Do **not** add a separate `ReflectionSummary` call; do **not** build the summary by
  concatenating `goalSummary` + `frictionSummary` for display.

**Files:** `AIService.swift`, extraction model/prompt.

**Done when:**
- [x] `ExtractionResult.summary` is populated on a normal dump.
- [x] Output is second-person, ≤28 words, reads as one natural sentence (spot-check 3+ dumps).
- [x] Existing `isActionable` / blockers / clarification behavior is unchanged.

**Notes:**
- Verified on 3 dumps (podcast 25w / novel 26w / running 16w) — all second-person, name goal +
  friction, no therapy-speak. `goalSummary` and blockers still generate correctly alongside.
- The on-device model can **refuse** a dump it deems sensitive — `extract` throws
  `GenerationError.Refusal ("May contain sensitive content")` (seen on a taxes + anxiety dump).
  This is pre-existing `FoundationModels` behavior, not introduced by the `summary` field;
  `clarify` / `generateNextStep` would refuse the same input. Added a `#if DEBUG` log of the
  caught error in `extract` to make refusals diagnosable. See T7 note below — today a refusal
  surfaces as the generic "Could not analyze your input. Please try again.", which dead-ends the
  user (retrying never helps).

---

### T4 — Reflection + Choice screen
**Status:** `[x]`  ·  **Depends on:** T3

**Goal:** Build the combined S2 screen (`ReflectionChoiceView`) per §5 and
`flow-2-hearing-choice.svg` — not yet wired into navigation.

**Scope:**
- Title **Here’s what I’m hearing**; **SUMMARY** card showing `ExtractionResult.summary`.
- Section **Which feels most true right now?** with the 3 generated `ClarificationOption` rows
  plus a static **Something else** row.
- Low-emphasis link **Edit what I wrote**.
- Tapping a generated option triggers next-step generation with that option’s `StuckMode`.
- Tapping **Edit what I wrote** returns to the brain dump with text preserved.
- Own AI state in a `@StateObject` view model; start any generation exactly once (never from
  `.onAppear`) so switching tabs and back does not re-analyze. See §7 *View-model ownership*.
- Layout: fits one viewport at default Dynamic Type; **scrolls gracefully** when content wraps
  or text is enlarged — never clip the **Something else** row or any control.

**Files:** new `ReflectionChoiceView.swift`.

**Done when:**
- [x] Screen matches `flow-2-hearing-choice.svg` including the **Edit what I wrote** link.
- [x] Renders correctly with a 2-line summary and a 2-line option at the largest Dynamic Type
      size (scrolls, nothing clipped). Verified live at `.accessibility5` via a temporary harness.
- [x] Selecting a generated option carries the correct `StuckMode` forward. *(Implemented:
      `model.select(option)` passes `option.mode` to `generateNextStep`; result published to
      `generatedStep`, view appends `.nextStep`. End-to-end nav confirmed in T5.)*
- [x] **Edit what I wrote** returns to the dump with the original text intact. *(Implemented:
      pops `path` to root; dump text persists via `@AppStorage`. Confirmed end-to-end in T5.)*

**Notes:**
- View model `ReflectionChoiceModel` lives in `ViewModels/` (separate file). All outputs are
  `@Published` (`options`, `isGenerating`, `generatedStep`, `errorMessage`); the view observes
  `generatedStep` via `.onChange` to navigate, then clears it (one-shot signal). No `.onAppear`
  generation, so a tab switch back never re-analyzes.
- The **Something else** row is present but static; its reroll behavior is T6.

---

### T5 — Navigation rewiring (single loader → Reflection + Choice)
**Status:** `[x]`  ·  **Depends on:** T4

**Goal:** Route the flow through the combined screen behind one loading state.

**Scope:**
- On **Find my next step**, run extraction + clarification-option generation behind the
  existing full-screen loader (copy: **Working on your reflection...**), then navigate to
  `ReflectionChoiceView` when both are ready.
- Replace the navigation destinations per §7: introduce `reflectionChoice(...)`; keep
  `nextStep(...)`.
- Leave the old `ReflectionView` / `ClarificationView` in the project for now (removed in T11).

**Files:** `AppDestination.swift`, the router/navigation glue, `BrainDumpView.swift`.

**Done when:**
- [x] Dump → single loader → `ReflectionChoiceView` works end to end.
- [x] No intermediate auto-advancing reflection screen appears.
- [x] The old separate reflection/clarification screens are no longer reachable in the flow.

**Notes:**
- `BrainDumpView.submit` now runs `extract` then `clarify` behind one loader
  ("Working on your reflection..."), then appends `.reflectionChoice`. Non-actionable input
  still shows the inline clarification prompt; errors still surface inline (T7 refines).
- Added `.reflectionChoice` to `AppDestination`; kept `.reflection` / `.clarification` because
  the Saved-tab "continue a step" path (`RecentStepDetailView`) still routes through them.
  T11 removes the old views, destinations, and reworks/retires that path.
- Verified live: dump → single loader → choice screen with real summary + 3 options (no
  intermediate reflection screen). Closed the two deferred T4 gates: selecting the
  overwhelmed/`.clarify` option produced a clarify-style next step (StuckMode forwarded), and
  **Edit what I wrote** returned to the dump with the original text intact.

---

### T6 — "Something else" reroll
**Status:** `[x]`  ·  **Depends on:** T5

**Goal:** Implement the no-typing correction path (§5).

**Scope:**
- Tapping **Something else** regenerates a fresh set of 3 options from the same brain dump,
  with a brief loading state. No text field / sheet.
- After one reroll that the user rejects, nudge toward **Edit what I wrote**.

**Files:** `ReflectionChoiceView.swift`, `AIService.swift`.

**Done when:**
- [x] **Something else** produces 3 new options without any typed input.
- [x] Each regenerated set still has one option per `StuckMode`.
- [x] After a second pass, the UI surfaces **Edit what I wrote** more prominently.

**Notes:**
- Reroll reuses `AIService.clarify(extraction:)` — same situation, fresh set from model
  nondeterminism. `ReflectionChoiceModel.somethingElse()` owns it (guarded against concurrent
  reroll/generation); a distinct `isRerolling` flag drives a "Finding other options..." loader.
- `rerollCount` drives the nudge: once ≥ 1, the link gains a hint line ("Still not quite right?…")
  and stronger styling (tint, semibold). Verified live + via logs: both sets had exactly 3
  options, one each for reproduce/narrow/clarify.

---

### T7 — Loading & partial-failure states
**Status:** `[x]`  ·  **Depends on:** T5

**Goal:** Make the combined load resilient (§11 acceptance criteria).

**Scope:**
- If extraction succeeds but clarification-option generation fails, still show the summary and
  offer **retry** plus **Edit what I wrote** — do not dead-end on the loader.
- If latency is high, hold the full-screen loader rather than showing partial reflection
  content.
- Distinguish a model **content-safety refusal** (`GenerationError.Refusal`) from a transient
  failure: a refusal will not succeed on retry, so show a "rephrase what you wrote" message and
  route to **Edit what I wrote** rather than a "Please try again." that dead-ends the user
  (see T3 notes).

**Files:** `ReflectionChoiceView.swift`, navigation glue, loader overlay.

**Done when:**
- [x] Simulated clarification failure shows summary + retry + **Edit what I wrote**.
- [x] Simulated extraction failure shows a concise error on the brain dump screen.
- [x] No state leaves the user stuck on a spinner.

**Notes:**
- `BrainDumpView` holds the single loader through `extract` + `clarify`. On clarify failure it
  navigates anyway with `clarification: nil`; `ReflectionChoiceView` shows the summary +
  "I couldn't load your options just now." + **Retry** + **Edit what I wrote**. Retry reruns
  `clarify`; verified failure → retry → recovered options live (temp first-call failure, since
  removed).
- Extraction failures stay on the dump. A content-safety **refusal** is mapped to
  `AIServiceError.contentRefused` ("…may be sensitive… Try rephrasing it.") and flagged
  non-retryable (`isRetryable`), distinct from the transient "Please try again." Verified with a
  real refusal (taxes + anxiety dump).
- `ReflectionChoiceModel` consolidated its three async ops behind one `busyMessage`/`run(...)`
  helper (replacing the separate `isGenerating`/`isRerolling` flags) so every path clears the
  loader in both success and failure — no stuck spinner.

---

### T8 — Next Step screen
**Status:** `[x]`  ·  **Depends on:** T5

**Goal:** Finish S3 per §5 and `flow-3-next-step.svg`.

**Scope:**
- Title **Here’s your next step**; **YOUR NEXT STEP** label; prominent step text; helper copy.
- Primary CTA **Start this step** (clears draft, returns to Unstick tab).
- Secondary **I’m still stuck** reveals the existing `fallbackStep` inline (does not return to
  the choice screen).
- **Save for later** stores the step in `RecommendedStepStore` and updates the Saved badge.
- **Come back tomorrow** only if T9 is in scope; otherwise omit the control entirely.

**Files:** `NextStepView.swift`, recommended-steps store.

**Done when:**
- [x] Screen matches `flow-3-next-step.svg`.
- [x] **Start this step** clears the draft and returns to the Unstick tab.
- [x] **I’m still stuck** reveals the fallback inline.
- [x] **Save for later** persists the step and it appears in the **Saved** tab with the badge
      incremented.

**Notes:**
- Logic extracted to `ViewModels/NextStepModel.swift` (still-stuck reveal/restart, save,
  confirmation); the store is injected via `init` (since `@StateObject` can’t read
  `@EnvironmentObject`), so `appDestinations` now takes a `store` parameter. Navigation (path
  reset) and draft clearing stay in the view.
- **Decision — "Come back tomorrow" omitted.** Mockup `flow-3-next-step.svg` shows only
  **I’m still stuck** + **Save for later**, and T9 is not in scope, so per T8’s rule the control
  is not rendered. `RecommendedStepStore.deferUntilTomorrow` remains for T9. The §13 open
  question (ship the deferred flow now or later) is still open.
- **Copy deviation — helper line.** §5 says "…not solve the whole app." Generalized to "…not
  solve the whole **thing**", since the app handles non-coding situations (garage, taxes, novel)
  where "app" is wrong. Flag if you want the literal wording.

---

### T9 — Come back tomorrow (deferred flow)
**Status:** `[x]`  ·  **Depends on:** T8  ·  **Decision: ship (see §13)**

**Goal:** Add the soft return point.

**Scope:** Implement per `come_back_tomorrow_spec.md` (defer creates one `RecommendedStep` with
`source == .deferredTomorrow`, clears draft, optional reminder, return card on next launch).
Per §14, the return card's **Start** / **Make it smaller** are a free resume and must never be
paywalled.

**Done when:**
- [x] Decision recorded: ship now (2026-06-19, §13).
- [x] Meets `come_back_tomorrow_spec.md` §10 acceptance criteria. *(Verified live — see notes.)*

**Notes:**
- Storage was already in place from T8 (`deferUntilTomorrow`, `dueDeferredStep`,
  `nextTomorrowAvailability`, `.deferredTomorrow`). T9 is the UI wiring on top.
- **S3 control:** `NextStepView` adds a low-emphasis **Come back tomorrow** below **Save for
  later**. Tapping it clears the draft and calls `NextStepModel.comeBackTomorrow()`, which
  defers exactly one step and shows a `.medium` confirmation sheet (`DeferConfirmationView`):
  "We'll hold this for tomorrow." + the §3 supporting copy, **Done**, and an optional
  **Set reminder**. Dismissing the sheet (Done or swipe) returns to a fresh Unstick tab.
- **Reminder:** `deferUntilTomorrow` now returns the computed `availableOn`; `DeferredReminder`
  (new) requests notification authorization on demand and schedules one local notification
  ("Unstuck" / "Ready to pick this back up?") at that date. Fully optional and non-blocking — a
  denial just means no reminder; the in-app return card still surfaces the step. Local
  notifications need no Info.plist key or entitlement.
- **Return affordance:** `BrainDumpView` shows `DeferredReturnCard` above the prompt when
  `stepStore.dueDeferredStep != nil`. **Collapsed by default to one quiet line** ("Pick up your
  step" + disclosure chevron) so it never competes with the dump (§4); tapping the row expands
  it ("Ready to pick this back up?" + step text + actions). Offers **Start** (hides the card for
  the session; the step stays active per §7), **Make it smaller** (reveals `fallbackText` inline;
  shown only when it exists; never regenerates), and **Let this go** (deletes immediately). Per
  §14 these are a free resume and must never be paywalled.
  - **Design revision (2026-06-19):** the first cut rendered the full multi-line card expanded by
    default, which pushed the title/prompt below the fold — the exact "tile competes with the
    primary job" problem §4 set out to fix. Reworked to the compact, tap-to-expand banner above
    (Option A of three reviewed mockups). Verified live: collapsed line → expand → Start /
    Make it smaller (reveals fallback, hides itself) / Let this go.
- **Deviation from §9:** when both a restored draft and a due deferred step exist, §9 wants the
  card *below* the draft; it currently renders above the prompt in both cases. Lower stakes now
  that it is a single collapsed line. Flag if the §9 ordering still matters.
- **Verified live** (iPhone 17 sim, on-device model): dump → choice → next step shows the new
  **Come back tomorrow** control → confirmation sheet ("We'll hold this for tomorrow.") →
  **Set reminder** fires the system notification prompt and flips to "✓ Reminder set" →
  **Done** clears the draft and returns to a fresh Unstick tab, with no card shown (deferred
  step not yet due, §9). Persisted record inspected: exactly one `deferredTomorrow` step,
  `isSaved=false`, `availableOn` next day 05:00 (>6h out), `expiresAt` = createdAt + 7d. Return
  card verified via a seeded due step: renders above the prompt; **Make it smaller** reveals the
  fallback inline and hides itself; **Let this go** deletes it and removes the card.

---

### T10 — Tests
**Status:** `[x]`  ·  **Depends on:** T5, T8

**Goal:** Lock in the behavior that matters.

**Scope:**
- Navigation: dump → reflection+choice → next step.
- Save behavior: **Save for later** updates the store and Saved badge.
- AI contract assumptions: extraction returns `summary`; clarification returns exactly 3
  options, one per `StuckMode`.
- Layout: S2 scrolls (no clipping) at the largest Dynamic Type size.

**Done when:**
- [x] Tests cover each item above and pass.
- [x] AI-contract tests fail loudly if the schema regresses.

**Notes:**
- 20 Swift Testing cases in `UnstickitTests.swift`, all passing on iPhone 17 (iOS 26.5 sim).
  Run: `xcodebuild test -scheme Unstickit -only-testing:UnstickitTests`.
- **Testability constraint:** the three AI stages call on-device `FoundationModels` via the
  `AIService.shared` singleton — non-deterministic and unavailable in CI, and not injectable. So
  tests cover the deterministic logic *around* the model; the model calls themselves stay covered
  by the live verifications recorded in T4/T5/T7/T9.
- **Coverage by scope item:**
  - *Navigation* — `AppNavigationTests` (startUnstickFresh / retry reset both paths + select
    Unstick) and `AppDestinationTests` (`.reflectionChoice` carries an optional clarification;
    distinct from `.nextStep`). The full dump→choice→step *traversal* runs through the model, so
    it is covered by the T5/T9 live runs rather than a unit test.
  - *Save behavior* — `SaveBehaviorTests` + `NextStepModelTests`: `saveForLater` adds exactly one
    `savedSteps` entry (the badge source); deferring does **not** inflate the badge; dismiss
    removes it.
  - *AI contract* — `AIContractTests`: `ExtractionResult.summary` and `ClarificationResult.options`
    are constructed directly (drop a field → won't compile), and `StuckMode` is pinned to exactly
    `{reproduce, narrow, clarify}` via an exhaustive switch (add a case → won't compile). The
    runtime "exactly 3 options" is model behavior (prompt-enforced, verified live).
  - *Layout (S2 Dynamic Type)* — **not** an automated test: reaching S2 requires the live AI
    flow and there is no snapshot lib / `AIService` injection point. Verified live at
    `.accessibility5` in T4. Automating it would need either DI for `AIService` or a snapshot
    dependency — out of T10 scope; flag if you want a follow-up ticket.
- Also added deterministic T9 coverage: `DeferredStepTests` pins the 5 AM / 6-hour-floor
  availability math, due-vs-not-due surfacing, and 7-day expiry purge.

---

### T11 — Cleanup
**Status:** `[x]`  ·  **Depends on:** T5–T8 stable

**Goal:** Remove dead code once the combined flow is proven.

**Scope:**
- Delete `ReflectionView` and `ClarificationView` and their old navigation destinations.
- Remove any now-unused MVP `ShareLink` save path.

**Done when:**
- [x] Old reflection/clarification views and destinations are gone.
- [x] Project builds with no unused-symbol warnings from the removed flow.
- [x] Single save mechanism remains (the local store).

**Notes:**
- Deleted `ReflectionView.swift` and `ClarificationView.swift`; removed the `.reflection` and
  `.clarification` cases from `AppDestination` and their switch arms in `RootTabView`.
- **Last consumer reworked:** the saved-step "continue" path (`RecentStepDetailView.submit()`)
  was the only remaining caller of `.reflection`. It now mirrors `BrainDumpView`: extraction +
  best-effort clarification behind one loader → `.reflectionChoice(...)`, so saved steps flow
  through the same combined screen (with the T7 retry-on-clarify-failure behavior).
- `ShareLink` was already gone — the local `RecommendedStepStore` is the single save mechanism.
- Build clean (no warnings), `grep` confirms no dangling references, all 20 T10 tests pass.

---

## 13. Resolved Decisions

- **Something else** regenerates a fresh set of 3 tappable options (no typed correction). This
  keeps the no-typing principle intact and avoids a free-text answer with no `StuckMode`.
- **I’m still stuck** reveals the existing `fallbackStep` inline; it does not return to the
  choice screen.
- The saved tab is named **Saved**.
- For MVP, the Saved tab shows only intentionally saved steps. Auto-collecting every generated
  step turns it into a history feature (post-MVP) and muddies the badge count.
- The save mechanism is a local `RecommendedStepStore`, replacing the MVP spec’s
  `ShareLink`-based "Save this step." Ship one save mechanism, not both. Note this pulls a
  slice of the post-MVP "session history" scope forward.

- **Come back tomorrow** ships in this redesign (T9). Resolved 2026-06-19: the deferred flow is
  a genuine day-2 retention affordance and it makes the planned monetization (see below) feel
  fair rather than punitive, so it is built now rather than left behind its own spec.

## 14. Monetization (recommendation, not yet built)

The product will be monetized with a paywall around **new** unstick flows. The exact free
allowance (e.g. first flow free, or N free dumps) is a tuning decision and is not specified
here; what matters for the design is **where** the gate sits.

**Recommendation — gate new dumps, never the return/resume of a deferred step.**

When a free user defers a step with **Come back tomorrow** and returns the next day, tapping
**Start** / **Make it smaller** on the return card must *not* hit the paywall. That moment is
the payoff the deferred flow promised ("When you come back, we'll start from this step",
`come_back_tomorrow_spec.md` §3), and its whole design ethos is no guilt, no pressure
(`come_back_tomorrow_spec.md` §1, §4). Paywalling it turns a trust affordance into a
bait-and-switch and will read as manipulative.

So:

- **Paywalled:** starting a *new* brain dump / **Find my next step** (subject to the free
  allowance).
- **Always free:** resuming a deferred or saved step from the return card or the Saved tab —
  the user already "paid" for that one in attention.

This funnel still works for conversion: the free day-2 win brings the user back into the app,
where a *new* dump is the natural, fair place to surface the paywall at a high-intent moment.

The paywall itself is **not implemented in this redesign** — this section records the intended
placement so the deferred flow (T9) is not later wired to gate the wrong moment.

### Still open

- Free allowance tuning for §14 (first flow free vs. N free dumps vs. trial). Does not affect
  T9 — only where/when the future paywall triggers on *new* dumps.

