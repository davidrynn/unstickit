# "Did this help?" — Next-Step Feedback & Regeneration

**Status:** Implemented 2026-07-15. Supersedes the "I'm still stuck" smaller-step reveal on
the next-step screen (S3) from `unstuck_mvp_spec.md` (the `fallbackStep` field survives as an
internal safety net and in persisted records, but has no user-facing reveal).

## Why

The on-device model occasionally hallucinates a detail into an otherwise good step (observed:
"work on the piece" for a ballet-lessons dump — no "piece" existed). Rather than adding more
prompt constraints — which earlier iterations showed degrades output quality overall — the
product accepts occasional misses and makes recovery cheap: the user says it didn't help,
optionally corrects the record, and gets a fresh step grounded in that correction.

This replaces two ambiguous affordances ("Got it" and "I'm still stuck") with one honest
question. The old "I'm still stuck" reveal surfaced a *generic template* step — exactly the
species of unhelpful output the AI work has been eliminating.

## Flow (S3)

After the step, the screen asks **"Did this help?"** with two equal buttons:

- **Yes** — accent-filled (the app's primary-action color; deliberately not a new green).
  Completes the session exactly as "Got it" did: record retained as completed, return to a
  fresh dump.
- **Not quite** — neutral secondary fill, *not red*: red stays reserved for the destructive
  "Delete & start over" below, and a stuck user shouldn't be punished for honest feedback.

Tapping **Not quite** expands inline:

1. An optional multiline field: *"What's off? Correct me or add a detail — optional"*.
2. A **Try again** button. Empty field → plain regeneration (one tap, zero typing burden).
   With text → the correction is folded into the Stage 3 retry prompt and explicitly
   overrides anything the model previously inferred.

Regeneration runs behind the shared loader ("Rethinking your step..."), replaces the step
in place, collapses the feedback UI, and re-fires the success haptic. The open-loop record
is re-recorded so completion/deferral always resolve the *visible* step.

## Retry cap

**Two regenerations per step.** After that, "Not quite" shows a nudge instead of the field:
*editing what you wrote usually helps more than another try*, with an **Edit what I wrote**
button that returns to the dump with the text preserved (`AppNavigation.retry(with:)`) and
discards this session's open loop. Mirrors the reflection screen's reroll nudge: past two
attempts, new input beats another roll.

## Pipeline (Stage 3 retry)

`AIService.regenerateNextStep(context:brainDump:rejectedStep:feedback:)`:

- `NextStepContext` (summary, mode, option label) is carried through the navigation payload
  from the reflection screen — the same inputs the original generation used.
- The retry prompt is the standard Stage 3 prompt plus a rejection block: the rejected step,
  "they said it did not help," the optional correction (marked as overriding), and an
  instruction not to repeat or rephrase the rejected suggestion.
- Same validation gates and one-shot repair as first-pass generation. Best-effort and
  non-throwing: any failure falls back to the deterministic template, so "Try again" always
  produces *something* new.

## Retry hardening (2026-07-15, same day)

First on-device session (ballet-lessons dump) exposed two failures:

1. **Invented artifact**: the step told the user to "open the ballet lesson planning
   document" — no such document exists; the lesson has to be created. (Same class as an
   invented email in a sibling session.)
2. **Retry parroted the rejection**: despite explicit feedback ("I don't know what planning
   document is… I have to create it myself"), the retry returned the identical sentence with
   one verb swapped (review → pick).

Fixes, all in `AIService`:

- **Similarity gate** (`StepValidationFailure.repeatedRejected`): on retries, a candidate
  with ≥80% word coverage against the rejected step is invalid — coverage, not containment,
  so one-word swaps are caught. The targeted repair names the failure; worst case lands on
  the template, which at least isn't the same hallucination twice.
- **Warmer retries**: first attempts stay at temperature 0.5 (instruction-following); retries
  sample at 0.9 — the low-temperature mode of the distribution is exactly what the user just
  rejected.
- **Correction promoted**: the user's feedback now sits with "Their situation" as an
  authoritative override, not a trailing note; the rejection block adds "if they said
  something does not exist, never mention it again — create its smallest first piece instead."
- **Anti-invented-artifact grounding** in the base Stage 3 prompt: never name a document,
  email, or tool the user didn't mention; if the thing doesn't exist yet, the first action is
  to create its smallest first piece, not to open it.

## Retry v2 (2026-07-15, later same day): constrained slot-fill

The hardened free-form retry still failed on-device: the base prompt's permit example was
parroted verbatim (twice — the user's dump happened to contain a real permit task, making the
example maximally attractive), and the warmer retry temperature produced grounded-but-nonsense
output ("Write the phone number for your son on a piece of paper"). Conclusion: free-form
generation after a rejection is beyond this model's reliable capability — every prompt fix
moved the failure rather than eliminating it.

New tiered design (the user's call: keep first-pass magic, buy retry reliability):

1. **First pass — open** (unchanged, minus the permit example, which is deleted; two sessions
   showed illustrative examples act as attractors for this model class). A mostly-right
   generated step that names the user's world beats a safe frame when no trust has been spent.
2. **"Not quite" retries — slot-fill.** The model never writes the sentence. It fills
   `StepIngredients`: `task` (2–10 words, must be ≥60% word-covered by the user's dump +
   correction — **groundedness is now validated in code**, so a hallucinated task is a caught
   failure, not a shipped one) and `firstAction` (2–8 words, imperative, may be generative —
   it names a move on something that may not exist yet). The step is assembled from a
   deterministic, mode-keyed frame, quoted to sidestep grammar mismatches. One targeted
   re-pick on slot rejection.

   *Frame revision (2026-07-15, fourth device session):* the retry mechanics worked (both
   retries picked verbatim tasks, sensible actions, zero hallucination) but the original
   frames were the problem — "Set a timer… then stop" read as gimmicky and patronizing, and
   when the user asked "Why a timer" the fixed frame answered with another timer. Frames are
   now plain — clarify: "Pick just one thing: “{task}”. {FirstAction}." / narrow: "Start
   with “{task}”. {FirstAction}." / reproduce: "Go back to “{task}”. Write down the last
   thing you tried and what actually happened." — and "then stop" was scrubbed from the
   deterministic templates too (telling an already-stuck user to stop reads as limiting).
   These are code strings, so no negative prompting was needed to remove them.
3. **Template** — final floor, unchanged.

*Ladder completion (2026-07-15):* the same three rungs now apply to the **first pass** too.
Previously a first-pass validation failure (e.g. the invented-artifact gate firing) dropped
straight to the canned template — observed on device as being shown "Write one sentence
finishing 'The thing I'm really stuck on is…'" as the *primary* step. Now `generateNextStep`
degrades open generation → slot-fill frame (grounded in the user's task, no rejection
context) → template, and the debug `SOURCE` line reports which rung produced the step
(`generated` / `assembled frame` / `fallback template`).

Rationale: the trust budget shrinks with each failure. The first pass gets one shot at an
open step; after a rejection, a second miss is what makes the product feel broken, so the
retry's worst case must be "right frame, suboptimal task choice" — never nonsense.

## Unchanged

"Delete & start over", the come-back-tomorrow defer flow, session-log semantics ("Yes" =
completed, exactly like "Got it"), and the silent open-loop record on appear.
