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

## Unchanged

"Delete & start over", the come-back-tomorrow defer flow, session-log semantics ("Yes" =
completed, exactly like "Got it"), and the silent open-loop record on appear.
