# ADR 0002 — Harden the unreliable on-device model instead of trusting it

## Status
Accepted

## Context
The on-device model chosen in ADR 0001 is small and fails often: it produces malformed structured
output, generates poor clarifying *questions*, duplicates options, and occasionally returns steps
that are too large or vague. A product that asks a stuck, low-bandwidth user to absorb a bad AI
response defeats its own purpose.

## Decision
Treat raw model output as untrusted and wrap every stage in product-side robustness:

- **Structured outputs** via `@Generable`/`@Guide` rather than free-text parsing.
- **Tappable options instead of typed free-response.** The model reliably generated poor
  clarifying questions, so Stage 2 emits exactly three first-person option phrases the user taps.
  This moves the hardest judgment (what kind of help is needed) to the user and leaves the model a
  constrained, reliable generation task.
- **Validation + dedup + repair-rerolls** when output violates the contract (e.g. fewer than 3
  distinct options).
- **Deterministic per-mode fallbacks** so a usable next step always renders even when generation
  fails outright.

## Consequences
+ The product degrades gracefully; the user never sees a broken AI response.
+ The robustness layer — not the happy path — is the genuine engineering signal.
+ Most logic is pure and unit-testable without live model calls.
− More code and more tests than "call the model and render the result."
− Fallbacks are generic by nature; they trade specificity for guaranteed usability.
