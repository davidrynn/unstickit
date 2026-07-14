# ADR 0006 — Defer RevenueCat integration until Pro is real

## Status
Accepted

## Context
`ship_unstickit_spec.md` originally listed RevenueCat as build-order step 3: integrate the SDK and
an app-level `isPro` owner as "plumbing now, paywall later," so Pro could be switched on without
re-architecting.

Re-examined against the actual state of the app, the cost/benefit inverts:

- There is **no paywall, no products, and nothing to gate** in the MVP (`monetization_spec.md`,
  ADR 0004). `isPro` would flip zero live features.
- Pro itself is post-MVP and **evidence-gated** — it may never ship if the recurrence assumption
  fails (ADR 0004). Plumbing for a feature that is not yet justified is speculative work.
- The re-architecting risk the original plan hedged against is small: a thin app-level `isPro`
  owner backed by `CustomerInfo` is roughly a half-day of work whenever a paywall is actually
  approached.
- Adding the SDK now introduces a third-party dependency to maintain and a privacy-label line item,
  for zero near-term functional gain — mild tension with the clean-privacy posture (ADR 0001/0003).

The evidence that gates Pro comes from the **session log** (`session_log_spec.md`, ADR 0004) and
anonymous analytics (ADR 0003) — not from payment plumbing. Those are what must ship first.

## Decision
**Defer RevenueCat (and the `isPro` state owner) out of the free-app ship track.** Build it as the
first step of the Pro track, only once Pro is greenlit by the evidence gate. Buying RevenueCat
rather than building entitlements remains the right call when that time comes (ADR 0003 stands);
this ADR changes only the **timing**, not the build-vs-buy choice.

This supersedes `ship_unstickit_spec.md §3` and removes RevenueCat from that spec's build order.

## Consequences
+ Fewer dependencies and a cleaner privacy label while shipping the free app.
+ Sequencing now matches the evidence-gated logic already established in ADR 0004 — payment
  plumbing follows the decision to monetize, not the other way around.
+ No speculative `isPro` machinery built before there is anything to gate.
− When Pro is greenlit, RevenueCat + `isPro` owner + a sandbox purchase must be done before the
  first paywall (accepted; ~half a day, tracked in the Pro track).
− `ship_unstickit_spec.md` and any checklist referencing "RevenueCat plumbing in MVP" must be
  updated to reflect this deferral.
