# AI Workflow Log

How AI was used to build this project — with the discipline that keeps it from becoming
"vibe-coded." The goal of this log is not to show that AI was used (table stakes) but that it was
used *responsibly*: spec-first, reviewed, and overridden where engineering judgment disagreed.

The most important entries here are the **"where I overrode it"** notes. Those are the evidence
that the judgment stayed human-owned.

## Working method

A repeatable, spec-first loop:

1. Write a small spec for the change (this repo has ~15 in `Docs/`).
2. Have AI pressure-test the spec for ambiguity, risk, and unstated assumptions.
3. Define acceptance criteria / tests.
4. Draft the implementation (AI-assisted).
5. Review manually — reject what doesn't fit the architecture.
6. Run tests.
7. Refactor deliberately; document the decision (ADR if significant).
8. Commit in small, reviewable chunks.

Tools: Claude Code (planning, spec review, implementation, refactors), Apple FoundationModels
(the on-device model the *product* runs on — distinct from the engineering workflow), Xcode +
swift-testing.

---

## Entries

### 2026-06-25 — Monetization & pattern-detection scoping *(reconstructed)*

**Goal.** Define a monetization model and the flagship Pro feature without compromising the
emotional contract or shipping unvalidated machinery.

**AI used for.** Drafting the canonical monetization model (`core free, gate features`) and
scoping pattern detection down to the smallest build that makes the Pro promise legible.

**Where engineering judgment led.**
- Kept pattern detection **post-MVP and gated on evidence** (observed retention + real subject
  recurrence) rather than building the aggregator/threading machinery speculatively. The MVP
  ships only a dumb append-only session log to accrue that evidence.
- Insisted the repeat-detection rule require ≥2 distinct `threadID`s so one stubborn problem
  revisited doesn't masquerade as a cross-session pattern — a correctness decision the original
  honest-copy claim ("same blocker 3×") could not otherwise support.

**Result.** `Docs/monetization_spec.md` (canonical) and `Docs/pattern_detection_spec.md`, with an
explicit MVP carve-out mirrored in `unstuck_mvp_spec.md`.

---

### Earlier — Core flow & on-device AI hardening *(reconstructed)*

**Goal.** Make a constrained, unreliable on-device model produce a trustworthy single next step.

**AI used for.** Drafting the 3-stage `@Generable` pipeline (extraction → reflection+choice →
next step), prompt wording, and unit tests.

**Where engineering judgment led.**
- Replaced typed free-response with **3 tappable options** after the on-device model reliably
  generated poor clarifying questions — moving the hardest judgment to the user's tap and leaving
  the model a constrained, reliable task.
- Added **validation + dedup/repair-rerolls + deterministic per-mode fallbacks** rather than
  trusting raw model output, because the small model fails often enough that the product can't
  depend on it.

**Result.** A working core loop that degrades gracefully when the model misbehaves — the
robustness story, not the happy path, is the engineering signal here.

> Note: the two reconstructed entries above were written after the fact from the specs and commit
> history. Going forward, add an entry at the time of the work.
