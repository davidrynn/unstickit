# ADR 0000 — Record architecture decisions

## Status
Accepted

## Context
The significant decisions — and, more importantly, the *reasoning and tradeoffs* behind them —
need to be legible to my future self and to anyone else who picks up this codebase. Decisions
captured only in commit messages or memory are not.

## Decision
Keep an ADR per significant decision in `Docs/adr/`, numbered sequentially. Each records context,
the decision, and consequences (including the downsides). Status is one of: Proposed, Accepted,
Superseded by NNNN. Keep them short — under a page.

A decision is "significant" if reversing it later would be expensive, or if a reasonable engineer
might have chosen differently. Routine choices do not get an ADR.

## Consequences
+ Decisions and their tradeoffs stay legible long after the context that produced them fades.
+ Cheap: most entries transcribe decisions already made across the specs in `Docs/`.
− A small ongoing discipline cost (write one when a real decision is made).

> Note: `Docs/` holds the longer product/feature specs; `Docs/adr/` holds these short decision
> records. The split is intentional — ADRs are decisions, specs are designs.
