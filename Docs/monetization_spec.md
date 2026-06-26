# Monetization Spec

Status: Canonical — source of truth for monetization
Owner: David Rynn
Last updated: 2026-06-25

> Single source of truth for monetization. Other specs defer to this document for the
> free/Pro line; they describe *where* their flows sit relative to it, not the policy.

## The model: core free, gate features

**Free helps you get unstuck cold. Pro learns how you get stuck and helps you over time.**

The core unstuck flow is **unlimited and free** — including starting new threads and
continuing existing ones. We monetize **value-add features**, never the relief itself.

| | Free | Pro |
|---|---|---|
| Unstuck flows (new + continue) | ✅ unlimited | ✅ |
| Come-back-tomorrow + reminder | ✅ | ✅ |
| Pattern detection ("learns how you get stuck") | — | ✅ |
| Full history / saved library | — | ✅ |
| Export / share | — | ✅ |
| Deeper modes | — | ✅ |

### The core flow is never gated

Starting a **new brain dump / new thread is free**, as is continuing or resuming any
thread. There is no allowance and no quota on the core action — the only thing a user is
ever asked to pay for is a Pro *feature* (the rows marked Pro above). Any future paywall
seam therefore sits at a Pro feature, never at thread creation.

## Why this model

- **On-device economics make it affordable.** The app runs 100% on Apple
  FoundationModels with near-zero marginal cost per session. "Unlimited free core" costs
  us essentially nothing — the reason cloud-based apps must meter usage does not apply.
  So we spend nothing to keep the strongest possible emotional contract: the relief is
  always free.
- **Protects the contract.** Never paywalling someone at the moment they're stuck is the
  cleanest, least-manipulative posture, and it aligns with the existing "no
  bait-and-switch / free resume" commitments in `come_back_tomorrow_spec.md`.
- **The trade-off, stated honestly:** this model has **no near-term revenue** — the paid
  features are post-MVP and unvalidated. That is acceptable and intentional: monetization
  here is downstream of proving retention, not a launch-day requirement.

## Timing

- **No paywall in the MVP.** (Consistent with `unstuck_mvp_spec.md §8`.)
- **Pro is post-MVP and gated on evidence** — observed retention plus real subject
  recurrence in the lightweight session log. The flagship Pro feature (pattern
  detection) and its go/no-go gating are specified in `pattern_detection_spec.md`.
- The Saved-tab "More is coming / Notify me" teaser (`ProInterestStore`) is the local
  demand probe feeding that decision and the natural precursor to the eventual paywall
  surface.

## Pricing direction (open)

- Because marginal cost is ~zero, a **one-time unlock** is viable and low-friction for a
  personal utility — and is the natural fit if early Pro is mostly "unlock the
  library / history."
- A **subscription** becomes defensible once **pattern detection** ships, because
  "learns you over time" delivers ongoing, compounding value rather than a one-time
  unlock.
- Likely path: one-time unlock first (if shipped before patterns) → subscription once
  patterns land. Exact pricing is a tuning decision, not fixed here.

## References

- `pattern_detection_spec.md` — the flagship Pro feature + its validation gating.
- `unstuck_mvp_spec.md` — MVP scope (no paywall; ships only the dumb session log).
- `flow_redesign_spec.md` §14 — defers to this spec for the free/Pro line.
- `continue_thread_resume_spec.md` §4 — defers to this spec; its continuation flows are free.
- `come_back_tomorrow_spec.md` — free-resume commitment (consistent: everything in the
  core flow is free).
