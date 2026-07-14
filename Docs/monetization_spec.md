# Monetization Spec

Status: Canonical — source of truth for monetization
Owner: David Rynn
Last updated: 2026-07-08

> Single source of truth for monetization. Other specs defer to this document for the
> free/Pro line; they describe *where* their flows sit relative to it, not the policy.

## The model: core free, gate features

**Free helps you get unstuck cold. Pro is the private record of everything you've gotten
unstuck on — and, later, what that record teaches you.**

The core unstuck flow is **unlimited and free** — including starting new threads and
continuing existing ones. We monetize **value-add features**, never the relief itself.

| | Free | Pro |
|---|---|---|
| Unstuck flows (new + continue) | ✅ unlimited | ✅ |
| Come-back-tomorrow + reminder | ✅ | ✅ |
| Full history / private archive | — | ✅ (near-term anchor) |
| Export / share | — | ✅ |
| Deeper modes (going further on a hard block) | — | ✅ |
| Pattern detection ("learns how you get stuck") | — | ✅ (later flagship) |

The **near-term Pro anchor is the private archive** — the body of work that accumulates as
you use the app. Pattern detection stays the *later* flagship: it is the payoff *of* that
archive, not a standalone feature, and it is gated on evidence (see Timing).

### The core flow is never gated

Starting a **new brain dump / new thread is free**, as is continuing or resuming any
thread. There is no allowance and no quota on the core action — the only thing a user is
ever asked to pay for is a Pro *feature* (the rows marked Pro above). Any future paywall
seam therefore sits at a Pro feature, never at thread creation, and never at the moment
someone is stuck.

## The guiding principle: monetize accumulation and depth, never cadence

The app is **episodic by design**: you get stuck, you do one thing, you leave — and you
may not be back for weeks. "Do one thing" *is* the premise, not a flaw to engineer around.
We will not fight it, and no monetization mechanic may quietly require it to be false.

The distinction that governs everything below:

- **Forced frequency** — the app manufacturing reasons to return (streaks, daily rituals,
  "keep your number alive" reminders, counts). **Banned.** It breaks the calm brand
  (`copy_principles.md`) and contradicts the "do one thing" premise.
- **Organic recurrence** — the user's *own life* bringing them back because they got stuck
  again, often on the same project. **Legitimate.** The app didn't demand it; reality did.
  Every visit is still "do one thing."

From this, one rule: **nothing we charge for may reward coming back more often.**
Monetization rewards *having used the app when genuinely stuck* — whenever that was. Value
may compound with **total** use over time; it must never compound with **cadence**.

Two things are monetizable under this rule, and only two:

1. **Accumulation** — the private, on-device body of work that grows with real use: the
   history / archive, revisiting a project you've been stuck on before, and (eventually)
   the patterns across it. Compounds with total use, indifferent to cadence.
2. **Depth** — going further on a *single* hard block ("deeper modes"). Intensity within
   one episode, requiring no return visit. Fully compatible with "do one thing."

## Retention precondition: keep what we currently discard

**This is the one purpose-safe move worth making now, independent of any pricing decision.**

Ground truth (2026-07-08 code audit): flows *are* saved automatically today (no "Save"
button), but **completed work is pruned.** Concretely:

- On the Next Step screen, a `RecommendedStep` is recorded silently as an open loop
  (`isSaved: false`). When the user taps **"Got it"** or **"Delete & start over,"**
  `resolveSession()` calls `RecommendedStepStore.delete(id:)` and the record is **gone**.
- The only thing that persists past resolution is a thin, **invisible** `SessionLogEntry`
  (an 84-char `brainDumpSnippet` + `chosenMode` + `blockerTypes`) — evidence-only, never
  surfaced to the user.
- The **Recent tab** (`RecentStepsView`) is live and functional, but it shows only *active*
  steps (open loops + explicitly saved/deferred ones); it **empties as work is completed.**
- **No project/thread grouping exists in the binary** — `StepThread` is spec-only
  (`continue_thread_resume_spec.md`). Each flow is currently independent.

**Implication:** we are currently *discarding the one asset* any future Pro feature (the
archive, or patterns) would monetize. Success deletes the record.

**Action:** retain completed sessions as a private, on-device record instead of pruning
them. This changes **nothing** about the flow, forces **no** frequency, and is the
highest-leverage, lowest-risk monetization-enabling move available. Decide the paywall
later; stop destroying the substrate now.

Retention is an **enabler, not itself a Pro feature.** The archive becomes Pro only when it
is *surfaced and queryable* (browse, search, "last time you were stuck on taxes, here's
what got you moving"). Preserving the data is free and should ship regardless.

This work is scoped as its own task in `retain_completed_sessions_spec.md`.

*(Tangential flag, tracked elsewhere: the `SessionLogEntry` write path is currently wired
and live, which is inconsistent with the release spec's claim that the session log is "not
in the 1.0 binary." That is a release-readiness reconciliation, not a monetization
decision — see `ship_unstickit_spec.md` / `session_log_spec.md`.)*

## Why this model

- **On-device economics make it affordable.** The app runs 100% on Apple
  FoundationModels with near-zero marginal cost per session. "Unlimited free core" costs
  us essentially nothing — the reason cloud-based apps must meter usage does not apply.
  So we spend nothing to keep the strongest possible emotional contract: the relief is
  always free.
- **Protects the contract.** Never paywalling someone at the moment they're stuck is the
  cleanest, least-manipulative posture, and it aligns with the existing "no
  bait-and-switch / free resume" commitments in `come_back_tomorrow_spec.md`.
- **Value that compounds without demanding cadence.** The private archive (and later,
  patterns) gets more useful the longer someone has used the app — but only in aggregate,
  never as a function of how *often* they return. This is the one revenue posture that fits
  an episodic utility without corrupting it into a habit-loop app.
- **The trade-off, stated honestly:** this model has **no near-term revenue** — the paid
  features are post-MVP and unvalidated. That is acceptable and intentional: monetization
  here is downstream of proving retention, not a launch-day requirement.

## Timing

- **No paywall, and no IAP, in 1.0.** A one-time unlock needs a feature behind it, and no
  Pro feature is built yet (the core is free by design; the archive/patterns are post-MVP).
  So **1.0 ships free with no in-app purchase** — this is correct, not a gap. (Consistent
  with `unstuck_mvp_spec.md §8`.)
- **Ship the retention precondition (above) whenever convenient** — it's purpose-safe and
  gates nothing, so it need not wait for the pricing decision.
- **Pro is post-MVP and gated on evidence** — observed retention plus real subject
  recurrence in the session log. The flagship Pro feature (pattern detection) and its
  go/no-go gating are specified in `pattern_detection_spec.md`.
- The Saved-tab "More is coming / Notify me" teaser (`ProInterestStore`) is the local
  demand probe feeding that decision and the natural precursor to the eventual paywall
  surface.

## Pricing direction (open)

**The mechanism, once there is something to sell, is a free app + a one-time,
non-consumable IAP unlock.** Pay once, own the extras forever; the core flow stays free.
This is what "one-time unlock" means here — *not* a price on the app itself.

Two models are explicitly **ruled out**:

- **Paid-upfront (charge to download).** Paywalls the relief *before* the user has felt it
  work, directly violating the core contract, and paid apps convert far worse in store
  discovery. The audience arrives stuck and skeptical; an upfront price loses them.
- **Tip jar (unlocks nothing).** Honest and zero-risk, but conversion is tiny and it reads
  oddly for a utility. Acceptable only as a last-resort fallback, not the plan.

Sequencing:

- **One-time unlock first.** The natural first paid extra is the *surfaced* private archive
  (which the retention precondition makes possible). A one-time unlock is low-friction and
  the right fit for a personal utility with near-zero marginal cost.
- **Subscription only once pattern detection ships** — because "learns you over time"
  delivers ongoing, compounding value rather than a one-time unlock. But because usage is
  episodic and we refuse to manufacture cadence, a recurring charge is the *harder* sell:
  it risks churning during the gaps between episodes. Lead with one-time; treat a
  subscription as a later, evidence-gated question, not a default.
- Exact price points are a tuning decision, not fixed here.

### Worth considering

- The price point may matter more than the Pro feature list. At a low enough tier (roughly
  impulse range) the purchase stops being a value calculation and becomes "I like this,
  sure" — which suggests pricing Pro cheaply could do more for conversion than adding
  features to it.
- The whole model presumes people want an *accumulated relationship with their own
  stuckness*, not just a fire extinguisher. That is the core unvalidated bet. Many users
  will want the rescue and nothing more; the archive/patterns layer is for the minority who
  don't — and that minority is who pays. The `ProInterestStore` teaser is the probe for
  whether they exist before any subscription is built.

## References

- `pattern_detection_spec.md` — the later flagship Pro feature + its validation gating.
- `unstuck_mvp_spec.md` — MVP scope (no paywall, no IAP; ships only the dumb session log).
- `flow_redesign_spec.md` §14 — defers to this spec for the free/Pro line.
- `continue_thread_resume_spec.md` §4 — defers to this spec; its continuation flows are
  free. Its `StepThread` is spec-only / unimplemented (see Retention precondition).
- `come_back_tomorrow_spec.md` — free-resume commitment (consistent: everything in the
  core flow is free).
- `ship_unstickit_spec.md` / `session_log_spec.md` — release-readiness reconciliation of the
  session-log write path (noted under Retention precondition).
