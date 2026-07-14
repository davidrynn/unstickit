# ADR 0001 — Keep Unstickit's core flow on-device

## Status
Accepted

## Context
Unstickit processes emotionally sensitive free text ("what I'm stuck on"). Two architectures were
available:

- **Cloud LLM** — a larger, more reliable model, but the user's raw text leaves the device, there
  is a per-session marginal cost, and a network/availability failure surface is introduced.
- **On-device LLM** (Apple FoundationModels) — a smaller, less reliable model, but raw text never
  leaves the phone, marginal cost is ~zero, and it works offline.

The product's promise is emotional safety and low friction. Cost matters because the monetization
model (`Docs/monetization_spec.md`) keeps the core flow unlimited and free.

## Decision
Run the entire core flow **on-device** via Apple FoundationModels. No raw user text leaves the
phone. Accept the weaker model and engineer around it with structured `@Generable` outputs,
validation, dedup/repair-rerolls, and deterministic per-mode fallbacks (see ADR 0002).

## Consequences
+ Strongest possible privacy story — the core differentiator.
+ ~Zero marginal cost makes "unlimited free core" economically trivial.
+ Works offline; no backend to operate for the core flow.
− Must engineer heavily around an unreliable small model.
− Cross-session intelligence (pattern detection) cannot run locally at quality; it is deferred to
  an opt-in cloud Pro tier (`Docs/pattern_detection_spec.md`), keeping the on-device default
  intact. See ADR 0004.
− Requires a capable device (Apple Intelligence); ineligible devices are gated out.
