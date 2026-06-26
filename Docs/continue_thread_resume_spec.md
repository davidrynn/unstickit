# Unstickit — Continue-the-Thread Resume Spec

## Status
**Draft** — proposed new behavior, specced into gated tickets (§10)

**Date:** 2026-06-22

**Depends on:** Recommended Steps (`recommended_steps_spec.md`), Come Back Tomorrow
(`come_back_tomorrow_spec.md`), Flow Redesign (`flow_redesign_spec.md`). Monetization
policy: `monetization_spec.md`.

---

## 1. The scenario

A user writes as much as they can about the issue they're stuck on, goes through the full flow
(S1 brain dump → S2 reflection + choice → S3 one next step), and acts on that step. Later — the
next day, or whenever they get blocked again — they **come back to the same issue and get the
next small step**, building the issue down over several sessions.

> One issue is a **thread**. Each return adds one more small step that builds on the last.

This is the day-2+ retention loop: a user can keep returning to an issue they already
started and keep moving it forward. It's free (`monetization_spec.md`); its job is
retention, and it's what gives the post-MVP Pro features something to learn from.

---

## 2. What exists today (and the gap)

Two re-entry surfaces already ship:

- **Come Back Tomorrow** (`come_back_tomorrow_spec.md`; code: `NextStepView` → `comeBackTomorrow()`
  → `RecommendedStepStore.deferUntilTomorrow`, return card `DeferredReturnCard` in `BrainDumpView`).
  On the next day a quiet card offers **Start / Make it smaller / Let this go**.
- **Saved tab** — saved steps reachable from `RecentStepsView`.

The gap is that **neither advances the issue**:

- The Come Back Tomorrow return card **Start** only *re-displays the same step* — no generation
  (`come_back_tomorrow_spec.md` §7: "Do not regenerate from the return card").
- The Saved-tab "Ready for the next step?" path (`RecentStepsView.submit` / `nextStepContext`)
  *does* generate, but it flattens a few stored fields into a one-shot string and re-runs the
  **whole** pipeline on a fresh `LanguageModelSession` (`AIService.swift:287`). It re-guesses the
  situation every time; the `StuckMode` already chosen, the summary already shown, and the steps
  already given are discarded. It restarts rather than continues.

So the trigger and the surface exist; **continuity does not.** This spec adds continuity.

---

## 3. Product intent & guardrails

- **Continued, not restarted.** A return is the next turn in one thread. The app remembers the
  goal, how the user was stuck, and the steps already given.
- **One small step per return — always.** Never a plan, roadmap, or checklist. The specs warn
  against this repeatedly (`flow_redesign_spec.md` §1 "one doable next step";
  `recommended_steps_spec.md` §8 "do not generate categories, priorities… would push toward
  project management"). The thread is **invisible context the model carries**, not a history the
  user scrolls. If we ever render the accumulated steps as a list, we have quietly become a task
  manager — don't.
- **Low pressure** (`come_back_tomorrow_spec.md` §1): a thread is a gentle record of progress,
  never a streak or accountability surface.
- **Tap-first**, not chat. The user adds at most one short "what changed" line; the interaction
  stays one chosen `StuckMode`, one step. Not a freeform conversation box.

Non-goals: a chat product; a visible plan; sync across devices (local-only, same as the other
specs).

---

## 4. Monetization: the core flow is free

Monetization policy is canonical in `monetization_spec.md`. For this spec the only thing
that matters: **nothing in the thread / continuation flow is gated.** Starting a new
thread, continuing an existing one, and re-surfacing a saved or deferred step are all
free. We monetize only Pro *features* (pattern detection, history/library, export), which
are post-MVP and sit outside these flows.

| Action | Gated? |
|---|---|
| New brain dump → new thread | Free |
| Continue an existing thread (return card / Saved → "Pick the next step") | Free |
| Re-surface an existing step (return card **Start**, no generation) | Free |

---

## 5. Design

### 5a. The `StepThread` model

A thread is the ordered record of turns for one issue. Its own model file (per the
"separate files for models" convention), not inlined.

```swift
// Models/StepThread.swift
struct StepThread: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    let originalBrainDump: String?   // the dump, stored once, not re-copied per turn
    var turns: [StepTurn]            // chronological, oldest first
}

struct StepTurn: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    var userNote: String?            // "what changed" on a return (nil for turn 1)
    var summary: String              // ExtractionResult.summary shown that turn
    var selectedMode: StuckMode      // the choice that drove this step
    var selectedOptionLabel: String
    var nextStep: String             // NextStepResult.nextStep
    var fallbackStep: String         // NextStepResult.fallbackStep
}
```

`RecommendedStep` gains one optional link so existing surfaces keep working unchanged:

```swift
var threadId: UUID?   // ties a saved/deferred step back to its thread
```

### 5b. AI contract — extend Stage 3, add no new round-trip

```swift
func generateNextStep(
    extraction: ExtractionResult,
    selectedMode: StuckMode,
    brainDump: String,
    selectedOptionLabel: String,
    priorTurns: [StepTurn] = []        // NEW — empty == today's exact behavior
) async throws -> NextStepResult
```

Inside `generateActivationStep`:

- `priorTurns` empty → build the prompt exactly as today (zero behavior change; protects turn 1
  and the existing tests).
- Non-empty → prepend a **compact, capped** thread preamble:

  ```
  Here is what this person has already worked through on this:
  - They were stuck like this: <turn.summary>
    You suggested: <turn.nextStep>
    Then they said: <turn.userNote>          // omit if nil
  (repeat, oldest → newest)

  Now continue the thread. Build on what they've already done — do NOT repeat a step they
  were already given. Give ONE tiny next action.
  ```

Capping (the small on-device model drifts with long context):

- Include at most the last **N** turns (start N = 3); always keep turn 1's summary as the anchor.
- Truncate each field before interpolation.
- Best-effort, same as today: on throw / refusal / failed validation, fall back to the
  deterministic per-mode template (`fallbackStep(for:)`). A continuation never hard-fails. Set
  copy expectations around "another small step," not "the next step in your plan" — the model
  will sometimes be uneven.

`extract` / `clarify` are unchanged.

### 5c. Continuity vs. a live session — why structured

A live `LanguageModelSession` transcript can't survive an app kill or a next-day return (it's
in-memory, not serializable), grows unbounded, and is opaque to test. A persisted structured
snapshot survives the next-day case (the whole point), keeps prompts bounded, and preserves the
deterministic-around-the-model testability the T10 notes rely on. So: **structured snapshot,
rebuilt into a capped preamble each turn** — not a carried session.

---

## 6. Flow

Both existing surfaces gain one continuation action. Both are **free** (§4).

### 6a. Come Back Tomorrow return card
`DeferredReturnCard` currently offers **Start / Make it smaller / Let this go** (`BrainDumpView.swift:197`).
Add one quiet action — **"Pick the next step"** — kept low-emphasis so it doesn't compete with the
calm re-show (the card is deliberately quiet per `flow_redesign_spec.md` §4):

- **Start** — unchanged: re-surface the existing step, no generation.
- **Pick the next step** — the continuation. Shows the single loader, then generates the next
  thread turn (§6c).
- **Make it smaller / Let this go** — unchanged.

### 6b. Saved tab
Replace the current "Ready for the next step?" reconstruct-and-restart path
(`RecentStepsView.submit`) with the thread-aware continuation (§6c) when the step has a
`threadId`. Steps without a thread (legacy / migration) fall back to today's string path — no
migration needed.

### 6c. The continuation turn

1. Show the existing single loader (**"Working on your reflection…"**).
2. **Skip re-extraction.** We already hold the last turn's `summary` and `selectedMode`. Offer an
   optional one-line "what changed since last time" → becomes `turn.userNote`.
3. **Carry the previous `StuckMode` forward by default** — the user already told us how they're
   stuck; don't re-ask. Provide a quiet **"Actually, it's changed"** that re-runs `clarify` and
   drops to the S2 Reflection + Choice screen to re-pick (reuses the T7 retry-on-clarify-failure
   path).
4. Call `generateNextStep(…, priorTurns: thread.turns)`.
5. Append the new `StepTurn`, bump `thread.updatedAt`, navigate to S3 with the new step.

Navigation stays state-based (`AppDestination` / shared nav state), consistent with the existing
`.reflectionChoice` / `.nextStep` routing — no new closure callbacks.

> **Default path:** "Pick the next step" goes straight to a generated S3 step (mode carried
> forward). S2 appears only when the user taps "Actually, it's changed." Fewer taps for the common
> "did it, what's next" case; the escape hatch covers a genuine pivot.

---

## 7. Persistence & lifecycle

- `StepThread` is **local-only, on-device**, through the Recommended Steps store
  (`recommended_steps_spec.md` §5). No sync.
- **Create on intent, not automatically.** A thread is materialized only when the user expresses
  keep/continue intent — **Save for later**, **Come back tomorrow**, or **Pick the next step** —
  the same explicit-intent gate as `recommended_steps_spec.md` §6 and consistent with §13's "don't
  auto-collect every step." Until then a turn lives only in in-memory view state.
- **Retention:** a thread lives as long as a `RecommendedStep` references it. When the last
  referencing step is gone (let go / expired-unsaved / never kept), purge the thread on the next
  cleanup pass. A saved step keeps its thread alive. Reuse the existing 7-day / 20-item purge in
  `RecommendedStepStore`.
- **Let this go** deletes the step; if nothing else references the thread, delete the thread too.

---

## 8. Privacy

- The thread stores `originalBrainDump` and per-turn `summary`/`userNote`, which can be sensitive.
  Same rule as `recommended_steps_spec.md` §3: **never display the raw brain dump in a list
  without an explicit reveal.** The thread is model context, not a scrollable UI surface.
- On-device only; deleting the step (or thread expiry) removes it. No export.
- The on-device model can **refuse** sensitive content (`GenerationError.Refusal`,
  `flow_redesign_spec.md` T3 notes). A refusal on a continuation turn must route to the
  rephrase/edit affordance and **must not corrupt or delete the existing thread**.

---

## 9. Open questions

- **N (thread depth in the prompt):** start at 3; tune against model reliability.
- **Mode drift:** if the user picks a different `StuckMode` mid-thread, keep one thread (the turn
  records its own mode) rather than forking. Recommended; confirm.
- **Return-card crowding:** adding "Pick the next step" puts a second primary-ish action on a card
  that §4 wants quiet. Watch the layout; it may need to live only in the expanded state.

---

## 10. Implementation Tickets

Each ticket is a self-contained, review-gated unit of work. Build them in order; **stop after
each and review against its "Done when" gate before starting the next.** A ticket is only
complete when every box in its gate is checked. If one balloons, split it rather than merging the
review.

Status legend: `[ ]` not started · `[~]` in progress · `[x]` done & reviewed.

---

### CT1 — Thread data model
**Status:** `[ ]`  ·  **Depends on:** none

**Goal:** Introduce the thread types and link them to the existing step record without changing
any behavior yet.

**Scope:**
- Add `StepThread` and `StepTurn` per §5a, each `Codable` / `Identifiable`, in their own files
  under `Models/` (separate files per the project convention — do not inline into a view).
- Add `var threadId: UUID?` to `RecommendedStep` (defaults to `nil`; existing records decode
  without migration).
- No persistence wiring, no generation changes, no UI — types and the field only.

**Files:** new `Models/StepThread.swift`; `Models/RecommendedStep.swift`.

**Done when:**
- [ ] `StepThread` / `StepTurn` exist and compile; `turns` is chronological (oldest first) by
      contract (documented on the property).
- [ ] `RecommendedStep` has `threadId: UUID?`; previously-persisted steps still decode (round-trip
      test of an old JSON payload without the field).
- [ ] No behavior change anywhere in the app; existing T10 tests still pass.

---

### CT2 — Thread persistence (create-on-intent, link, purge)
**Status:** `[ ]`  ·  **Depends on:** CT1

**Goal:** Store threads locally and tie their lifecycle to the steps that reference them (§7).

**Scope:**
- Persist `[StepThread]` in `RecommendedStepStore` (same local on-device storage as steps; no sync).
- **Create on intent only** — a thread is materialized when the user taps **Save for later**,
  **Come back tomorrow**, or (later) **Pick the next step**; never automatically per generated
  step (consistent with §13 and `recommended_steps_spec.md` §6). Set `RecommendedStep.threadId`
  when the step is created from such an intent.
- Append-turn API: `appendTurn(_:toThread:)` that also bumps `updatedAt`.
- **Purge-with-step:** when the last `RecommendedStep` referencing a thread is gone (let go /
  expired-unsaved / never kept), delete the thread on the next cleanup pass; a saved step keeps its
  thread alive. Fold into the existing 7-day / 20-item purge.

**Files:** `Models/RecommendedStepStore.swift`.

**Done when:**
- [ ] Save / defer creates exactly one thread with one turn and links `threadId`; a plain
      **Start this step** (no keep intent) creates **no** thread.
- [ ] `appendTurn` adds in chronological order and updates `updatedAt`.
- [ ] Deleting / expiring the last referencing step purges its thread; a saved step does not.
- [ ] No orphan threads remain after a purge pass (asserted in a store test).

---

### CT3 — Thread-aware next-step generation
**Status:** `[ ]`  ·  **Depends on:** CT1

**Goal:** Let Stage 3 continue a thread, with the `priorTurns: []` path byte-for-byte identical to
today.

**Scope:**
- Add `priorTurns: [StepTurn] = []` to `generateNextStep` (§5b).
- When empty, build the prompt exactly as today — **no change** to the existing call site's output.
- When non-empty, prepend the capped thread preamble (§5b): last **N = 3** turns, always keeping
  turn 1's summary as the anchor; truncate each interpolated field; instruct "do NOT repeat a step
  already given."
- Keep the best-effort contract: on throw / refusal / failed validation, fall back to the
  deterministic per-mode template. A continuation never hard-fails.
- Make `N` and the per-field truncation lengths named constants.

**Files:** `AI/AIService.swift`.

**Done when:**
- [ ] `generateNextStep(..., priorTurns: [])` produces the same result shape and prompt as before
      (pinned by a test asserting the empty path is unchanged).
- [ ] With ≥1 prior turn, the assembled prompt includes the capped preamble and the no-repeat
      instruction; with > N turns, only the last N (plus the turn-1 anchor) appear.
- [ ] A simulated refusal/throw on a continuation turn returns the template fallback, not an error.
- [ ] Spot-check live (3+ threads): the continuation step builds on the prior step and does not
      simply restate it.

---

### CT4 — "Pick the next step" on the return card
**Status:** `[ ]`  ·  **Depends on:** CT2, CT3

**Goal:** Add the continuation entry point to the Come Back Tomorrow return card (§6a, §6c) — free,
state-based, mode carried forward.

**Scope:**
- Add a low-emphasis **Pick the next step** action to `DeferredReturnCard` alongside the existing
  **Start** (which stays a no-generation re-show). Keep the card quiet (§4 / `flow_redesign_spec.md`
  §4) — the new action lives in the expanded state, not the collapsed line.
- Tapping it: single loader (**"Working on your reflection…"**) → skip re-extraction → carry the
  last turn's `StuckMode` forward → optional one-line "what changed" (`userNote`) →
  `generateNextStep(..., priorTurns:)` → append the turn → navigate to S3.
- Navigation is state-based (`AppDestination` / shared nav state); no closure callbacks.

**Files:** `Views/BrainDumpView.swift` (`DeferredReturnCard`), navigation glue, a continuation
view model under `ViewModels/` (own AI state in a `@StateObject`; start generation exactly once,
never from `.onAppear`, per `flow_redesign_spec.md` §7).

**Done when:**
- [ ] The return card shows **Pick the next step** (expanded state only); **Start** still
      re-surfaces the existing step with no model call.
- [ ] Tapping it generates a new step that carries the prior `StuckMode` and appends one `StepTurn`
      to the thread.
- [ ] The collapsed return card is unchanged (still one quiet line; §4 not regressed).
- [ ] End-to-end verified live: defer → next day → **Pick the next step** → new S3 step that
      builds on the last.

---

### CT5 — Saved-tab continuation
**Status:** `[ ]`  ·  **Depends on:** CT2, CT3

**Goal:** Make the Saved-tab "continue a step" path thread-aware, replacing the
reconstruct-and-restart string path when a thread exists (§6b).

**Scope:**
- When the step has a `threadId`, route "continue" through `generateNextStep(..., priorTurns:)`
  (the continuation turn, §6c) instead of `nextStepContext`'s flattened-string re-extraction.
- Steps **without** a `threadId` (legacy, pre-CT1) keep today's string fallback — no migration.
- Reuse the CT4 continuation view model so both surfaces share one path.

**Files:** `Views/RecentStepsView.swift`, the continuation view model.

**Done when:**
- [ ] A saved step with a thread continues via `priorTurns` and appends a turn; no full
      re-extraction occurs.
- [ ] A legacy saved step (no `threadId`) still works via the existing string path.
- [ ] Both return-card and Saved-tab continuations go through the same view model (no duplicated
      generation logic).

---

### CT6 — "Actually, it's changed" pivot
**Status:** `[ ]`  ·  **Depends on:** CT4

**Goal:** Give the user an escape hatch from the carried-forward mode back to a fresh choice (§6c).

**Scope:**
- Add a quiet **Actually, it's changed** action on the continuation path.
- It re-runs `clarify` and routes to the S2 Reflection + Choice screen so the user re-picks a
  `StuckMode`; selecting an option then runs the continuation turn with the new mode.
- Reuse the T7 retry-on-clarify-failure behavior — never dead-end on the loader.

**Files:** the continuation view model, `Views/ReflectionChoiceView.swift`, navigation glue.

**Done when:**
- [ ] **Actually, it's changed** lands on S2 with freshly generated options.
- [ ] Re-picking a different mode produces a continuation step under the new `StuckMode`, still
      appended to the same thread (no fork — §9).
- [ ] A clarify failure on this path shows retry + **Edit what I wrote**, not a spinner dead-end.

---

### CT7 — Continuation resilience (failure & refusal)
**Status:** `[ ]`  ·  **Depends on:** CT3, CT4

**Goal:** Ensure a failed or refused continuation never strands the user or corrupts the thread (§8).

**Scope:**
- On a transient failure, surface a concise retry; the thread and prior turns are untouched (no
  partial turn appended).
- On a content-safety **refusal** (`GenerationError.Refusal`), route to the rephrase/edit
  affordance (non-retryable, per `flow_redesign_spec.md` T7), not "please try again."
- Only append a `StepTurn` on a successful generation (or the deterministic fallback) — never on a
  thrown/refused turn.

**Files:** the continuation view model, `Models/RecommendedStepStore.swift`.

**Done when:**
- [ ] Simulated transient failure: retry works; no orphan/partial turn in the thread.
- [ ] Simulated refusal: rephrase/edit affordance shown, marked non-retryable; thread unchanged.
- [ ] No continuation path leaves the user stuck on a spinner.

---

### CT8 — No core-flow paywall
**Status:** `[x]` (nothing to build)  ·  **Depends on:** —

Per `monetization_spec.md` the core flow is free and unlimited: new-thread creation and
every continuation / resume path carry no paywall. There is **no thread-gating seam** to
build here. Any future paywall sits at a Pro *feature* (see `pattern_detection_spec.md`),
never in these flows.

---

### CT9 — Tests
**Status:** `[ ]`  ·  **Depends on:** CT3, CT5

**Goal:** Lock in the thread behavior that matters, deterministically (around the non-injectable
on-device model, per the T10 testability constraint).

**Scope:**
- Persistence: append ordering, create-on-intent (no thread on plain Start), purge-with-step,
  no orphan threads.
- AI contract: `generateNextStep(priorTurns: [])` output equals the legacy path; capped preamble
  includes only N (+ anchor) turns and the no-repeat instruction.
- Legacy: a saved step with no `threadId` still continues via the string fallback.

**Files:** `UnstickitTests.swift` (new cases alongside the existing 20).

**Done when:**
- [ ] Tests cover each item above and pass on the iPhone 17 (iOS 26.x) sim.
- [ ] Contract tests fail loudly if `priorTurns: []` ever diverges from legacy output or the cap
      regresses.
- [ ] Live-only items (model quality of "builds on, doesn't repeat") are recorded as verified in
      the relevant ticket notes, not asserted in unit tests.
```
