# ADR 0004 — Defer pattern detection until the recurrence assumption is validated

## Status
Accepted

## Context
The flagship Pro feature is pattern detection — "the app learns how *you* get stuck." It rests on
an unvalidated assumption: that users get stuck on *recurring* subjects often enough that
detecting it is valuable. If most stuck-moments are one-off, the entire Pro pitch collapses, and
the machinery it needs (`repeatSubjectKey`, `threadID` propagation, aggregator, synthesis) would
be built on sand. The feature also has zero value on day one of any user's life — it needs
accumulated multi-session history to show anything.

## Decision
Ship pattern detection **post-MVP, gated on evidence**, not speculatively. In the MVP, ship only a
**dumb append-only session log** (a handful of fields written on resolve). Build the real engine
only after two observations from that log: (a) the core loop retains users, and (b) real subject
recurrence exists across separate sessions/threads.

When built, enforce a strict repeat rule (≥3 resolved sessions, trailing 30 days, matching subject
key, across **≥2 distinct threadIDs**, excluding in-session retries) so a single revisited problem
cannot masquerade as a cross-session pattern.

## Consequences
+ No expensive machinery built before the assumption it depends on is proven.
+ The session log accrues fuel silently, avoiding a cold start the day the feature ships.
− No near-term Pro revenue from this feature (acceptable: monetization is downstream of proving
  retention, per `Docs/monetization_spec.md`).
− Requires shipping the log early even though it surfaces nothing to users yet.
