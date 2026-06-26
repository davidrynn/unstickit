# Pattern Detection Spec

Status: Draft
Owner: David Rynn
Last updated: 2026-06-25

## Background

### What the app does today

Unstickit helps a person get unstuck in the moment. The whole app is two tabs —
**Unstick** (the flow) and **Saved** — and runs entirely on-device via Apple's
FoundationModels framework (no cloud, no API, near-zero marginal cost per session).

The core flow is a 3-stage pipeline:

1. **Brain dump** — the user free-types whatever they're stuck on.
2. **Extraction** — the model summarizes the goal, identifies 1–3 typed blockers
   (practical / informational / emotional), and surfaces a one-line "what I noticed"
   insight about the current dump.
3. **Reflection + choice** — the user taps one of three "which feels most true"
   phrases (each silently mapped to a stuck *mode*: reproduce / narrow / clarify).
4. **Next step** — one tiny ~2-minute concrete action. From there the user can start
   it, say "I'm still stuck" (reveals a smaller step), save it for later, or defer it
   to tomorrow (with an optional reminder).

Saved and deferred steps persist in UserDefaults; a deferral can schedule a single
local notification. That is the complete, working product.

### The problem we're solving

We want to monetize, and right now there is almost nothing worth charging for. The
only feature that exists and could be gated is the saved-steps list — which is the
weakest possible thing to sell ("pay to save your history"), and exactly the framing
we've decided to avoid. The compelling Pro story — "the app learns how *you* get
stuck and gets better at helping you" — does not exist in code yet. Every piece of it
(cross-session pattern detection, projects, smart follow-ups, export) would have to be
built; pattern detection is the largest and most load-bearing unbuilt piece.

The monetization positioning we've converged on:

> **Free helps you get unstuck cold. Pro learns how you get stuck and gets better at
> helping you.**

This spec scopes the smallest build that makes that Pro promise real and legible.

## Phasing / MVP boundary

**This feature is post-MVP. Do not build the full thing as part of the MVP.** It is
structurally a later phase for one decisive reason: it has zero value until a user has
accumulated multiple sessions on recurring subjects — which is exactly what the MVP
exists to test. On day 1 of any user's life there is no pattern to show, and you cannot
even tell the feature works until you have retained users generating multi-session data.

It also rests on an **unvalidated assumption**: that users get stuck on *similar /
recurring* things often enough that detecting it is valuable. If most stuck-moments are
one-off and diverse, the whole Pro pitch collapses — and the expensive machinery here
(`repeatSubjectKey`, `threadID` propagation, aggregator, synthesis) would be built on
sand. Validate the assumption with real data before building the engine.

What this means concretely:

- **In MVP — ship only a dumb append-only session log.** On each resolved session,
  append `createdAt`, `brainDumpSnippet`, `chosenMode`, and `blockerTypes` to a flat
  log. **No** `repeatSubjectKey`, **no** `threadID` threading, **no** surfaces, **no**
  paywall. This is a handful of fields written on resolve. Its only jobs: (1) accrue
  history silently so the feature has fuel the day it ships instead of a cold start, and
  (2) let *you* eyeball whether subject recurrence is actually real.
- **Post-MVP, gated on evidence — build everything else in this spec.** Gate on two
  observations from the MVP log: (a) the core loop retains users, and (b) real subject
  recurrence exists across separate sessions. Only then is the repeat key / thread /
  aggregator / synthesis / paywall worth the effort.

The MVP carve-out is mirrored in `unstuck_mvp_spec.md` (§6 Data Model, §8 Out of Scope).

## Purpose

Give the app a credible "it learns how you get stuck" story so there is something
worth charging for. Today the only gateable feature that exists is the saved-steps
list, which is the weakest possible thing to sell. The compelling Pro value —
personalization across sessions — does not exist yet. This spec scopes the minimum
build that makes that promise **visible enough to charge for**.

Two product levers this is designed to deliver:

1. **Personalization visible before purchase.** The user must *see* a real, observed
   pattern about themselves before paying — not a promise of future value.
2. **A concrete conversion trigger.** The "you've hit this same blocker 3 times this
   month" moment, fired at the repeat-stuck point — not a generic "want more?" prompt.

## Key insight

The app already generates the richest signal it needs and then discards it. Stage 1
produces typed `Blocker`s and a per-session `whatINoticed` insight; Stage 2 produces
the chosen `StuckMode`. None of this is persisted. Only `text`, `source`,
`originalBrainDump`, and `createdAt` survive (see `RecommendedStep`). So this is not
"build pattern detection from scratch" — it is "stop throwing the signal away, then
count it."

## Scope

### In scope
- Persist per-session signal (the keystone).
- Deterministic aggregation over the trailing window (counts + repeat detection).
- One on-device model synthesis call for the warm narrative (Pro surface).
- Two UI surfaces: a free teaser line and a Pro patterns panel.
- A simple `isPro` flag to gate the Pro surface (no StoreKit yet).

### Explicitly out of scope (for this slice)
- Projects / grouping.
- Export / share.
- Charts or visualizations.
- Smart / personalized follow-up reminders.
- StoreKit / IAP / purchase flow (gate behind a flag; wire purchases later).

## Design

> The lifecycle decisions below (session context, two-phase logging, the repeat key,
> the thread id, and the explicit repeat rule) came out of a code-grounded review.
> They exist because the current flow does **not** have a clean "resolve once, log
> once" moment, and because the original honest-copy claim ("same blocker 3×") was not
> supportable by the existing data model. Do not simplify them away without re-reading
> that reasoning.

### 1. Keystone — capture what we already compute

Add a separate, append-only `SessionSignal` log. Do **not** bolt this onto
`RecommendedStep`: that model has save/unsave/purge/20-cap semantics tuned for the
Saved tab, and it only keeps steps the user chose to save. Patterns live especially in
the sessions the user *bailed* on, so we need to log every resolved session, saved or
not.

**Two-phase logging via a `SessionContext`.** The signal is not available in one place.
The chosen mode exists transiently in `ReflectionChoiceModel` when the user taps an
option; the outcome (saved / deferred / bailed) only lands later in `NextStepModel`.
So thread a mutable `SessionContext` through navigation that accumulates the signal as
the user moves through stages, then write/finalize the `SessionSignal` when the session
resolves. (Equivalent alternative: write a partial record at step-shown, update its
outcome flags later. Either way it is two-phase, not single-shot.)

```
SessionSignal:
  id: UUID
  threadID: UUID                  // identifies one stuck-thread across continuations
  origin: SessionOrigin           // .fresh | .continueFromSaved | .deferredReturn | .stillStuckRetry
  createdAt: Date
  brainDumpSnippet: String        // short, for synthesis context
  chosenMode: StuckMode
  blockerTypes: [BlockerType]
  whatINoticed: String
  repeatSubjectKey: String        // canonical noun-phrase key, matching only — never shown
  repeatSubjectLabel: String      // human-readable subject, for UI copy
  didSaveStep: Bool
  didDefer: Bool
  didBailStillStuck: Bool
```

- Stored in UserDefaults via Codable, mirroring `RecommendedStepStore`. No new infra,
  no migration risk to existing saved steps.
- `threadID` + `origin` distinguish a genuinely new stuck episode from a continuation
  of an existing one. The app already has three continuation paths that re-run the
  pipeline — continue-from-saved (`RecentStepsView`), the deferred-return card
  (`BrainDumpView`), and the "I'm still stuck" retry (`NextStepView`) — and without
  this field a single stubborn problem revisited three times would masquerade as a
  cross-session pattern. A continuation inherits the originating session's `threadID`;
  a fresh brain dump gets a new one.
- This is ~80% of the total effort; everything else depends on it.

#### `repeatSubjectKey` — a stable, model-derived match key

Add a 4th Stage-1 `@Generable` field rather than normalizing prose after the fact.
`goalSummary` is too sentence-shaped and intent/friction-heavy; it drifts. The model
derives a canonical key instead, under a strict prompt contract:

- `repeatSubjectKey`: 2–5 lowercase words, noun phrase, **no** feelings/process words,
  no punctuation. Used for matching only — **never shown to the user**.
- `repeatSubjectLabel`: the human-readable subject, used for any UI copy.

A model-derived key is still imperfect, but it is more honest and testable than
post-hoc string matching, and it is what makes the repeat claim defensible.

### 2. Deterministic aggregation (no model, instant, cannot hallucinate)

A pure function over the trailing window of `SessionSignal`s:

- Tally `chosenMode` → e.g. "narrow came up in 4 of your last 6."
- Tally `blockerTypes` → e.g. "mostly emotional blockers lately."
- **Repeat detection** → the conversion trigger, defined by the explicit rule below.

Fully unit-testable, zero model calls.

#### Repeat rule (define before implementing)

Do **not** use "distinct threads sharing a subject key" alone. The trigger fires when:

```
repeat = >= 3 resolved sessions
         within the trailing 30 days
         where repeatSubjectKey matches
         across >= 2 distinct threadIDs
         excluding immediate in-session "I'm still stuck" retries from the count
```

In-session retries are still **logged** as useful behavioral signal, but they must not
fire the cross-session purchase trigger. This keeps the monetization claim clean:
"this keeps coming back" must mean recurring across *separate attempts*, not one hard
session generating multiple events. Note: the cross-session trigger is deliberately
distinct from the in-session "I'm still stuck" button — the latter is immediate friction
within one attempt, not evidence of a recurring pattern.

### 3. Model synthesis (Pro surface only)

A new `@Generable PatternInsight` fed the trailing `whatINoticed` lines + snippets,
producing the warm narrative ("Across your recent stucks, the theme is starting, not
finishing"). On-device FoundationModels, near-zero marginal cost, mirrors the existing
3-stage AIService pattern.

## Surfaces

- **Free teaser (lever 1):** the deterministic line shown after a session — "This is
  the 3rd time something like this has surfaced." Real, observed, no model. This is
  personalization the user can see before paying.
- **Conversion trigger (lever 2):** the repeat rule (cross-session, ≥2 distinct
  threads) fires the upsell when a subject genuinely recurs — not when one session is
  hard.
- **Pro panel:** the synthesized narrative + full tallies, gated behind `isPro`.

## Risks

- **Cold start.** The teaser is only as good as data volume. With 2 sessions there is
  no pattern. The free teaser must stay silent until the repeat rule is satisfied, or
  it reads as broken.
- **Repeat-key drift.** A model-derived `repeatSubjectKey` can phrase the same subject
  two ways and miss a match (false negative) or collapse distinct subjects (false
  positive). Enforce the strict prompt contract, keep the key internal, and unit-test
  the matching against fixture sessions. Prefer under-firing the trigger to
  over-claiming a pattern that isn't there.
- **Revisit-vs-pattern confusion.** Without `threadID`/`origin`, one stubborn problem
  revisited looks like a recurring pattern. The repeat rule's "≥2 distinct threadIDs"
  clause is the guard; it must not be dropped.

## Build order

> This is the **post-MVP** sequence, gated on the evidence described in *Phasing / MVP
> boundary*. The MVP ships only the dumb append-only log; the steps below upgrade that
> log into the real feature once retention and recurrence are observed.

1. **Plumbing first (not optional):** make `StuckMode` and `BlockerType` `Codable`
   (they are not today), and introduce a real `isPro` state owner — there is no
   app-level Pro state yet, so the gate needs an owner comparable to how `RootTabView`
   owns app state, not just a view-local conditional.
2. `SessionContext` + `SessionSignal` model + store + two-phase write wiring
   (signal accumulated through nav, finalized on resolve), including `threadID`/`origin`
   propagation across the three continuation paths. Self-contained first feature PR;
   nothing else can be built or tested until this exists.
3. `repeatSubjectKey` / `repeatSubjectLabel` as a Stage-1 `@Generable` field under the
   strict prompt contract.
4. Deterministic aggregator implementing the explicit repeat rule + unit tests
   (small, isolated, pure; test the repeat rule against fixture sessions).
5. `PatternInsight` @Generable + one AIService method (mirrors existing stages).
6. Two surfaces: free teaser line, Pro panel behind `isPro`.

## References

- `Unstickit/Models/RecommendedStep.swift` — current persisted shape.
- `Unstickit/Models/RecommendedStepStore.swift` — storage pattern to mirror.
- `Unstickit/AI/AITypes.swift` — `StuckMode`, `Blocker`, `BlockerType`, `whatINoticed`
  (note: `StuckMode`/`BlockerType` are not `Codable` yet).
- `Unstickit/AI/AIService.swift` — 3-stage generation to mirror for synthesis.
- `Unstickit/ViewModels/ReflectionChoiceModel.swift` — where the chosen mode lives
  transiently; source for the `SessionContext` capture.
- `Unstickit/ViewModels/NextStepModel.swift` — where outcomes (save/defer/still-stuck)
  land; the second phase of logging.
- `Unstickit/Views/RecentStepsView.swift`, `Unstickit/Views/BrainDumpView.swift`,
  `Unstickit/Views/NextStepView.swift` — the three continuation paths that must
  propagate `threadID`/`origin`.
- `Unstickit/Views/RootTabView.swift` — model for where app-level `isPro` state should
  be owned.
