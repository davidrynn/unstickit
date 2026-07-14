# Unstick — MVP Spec

## Status
**Draft** — derived from Plan Iteration 3 + resolved open questions

> **Partially superseded by `flow_redesign_spec.md` (2026-06-15).** The redesign is the source
> of truth for the post-dump flow and navigation. Specifically, it replaces:
> - §3 S2 (Reflection) and S3 (Clarification) — now one combined **Reflection + Choice** screen
> - §3 S1 CTA "Help me think this through" — now **Find my next step**
> - §3 S4 "Save this step" via `ShareLink` — now **Save for later** via a local
>   `RecommendedStepStore` surfaced in a **Saved** tab
> - the single-screen root — now a **TabView** (Unstick / Saved)
>
> Sections below marked _(superseded)_ are retained for rationale only. The AI contracts (§5)
> and draft persistence remain in force except where the redesign amends them.

---

## 1. Product Summary

**App name:** Unstick
**Core promise:** When you're stuck, the app gets you back to working.
**Primary goal:** Re-engagement — get the user back in motion. The step does not need to be
the right step. It does not need to move toward the solution. It just needs to be easier to
do than to avoid, so the user gets back in the saddle.

---

## 2. Device Requirements

- iOS 18.1 or later
- Apple Intelligence enabled
- A17 Pro chip or later (iPhone 15 Pro, iPhone 16 series)
- If device is ineligible, show **Screen S0: Apple Intelligence Required** and block entry.

---

## 3. Screens — superseded

The original S0–S4 screen definitions and draft-persistence/transition details now live in
`flow_redesign_spec.md` (screens, copy, navigation) and `recommended_steps_spec.md` (the
"Save for later" path that replaced the old `ShareLink`-to-Reminders "Save this step" button).
The one piece from S3 worth carrying forward as rationale, not spec, is *why* the flow uses
tappable options instead of typed answers: early versions asked the user to type a response to
an AI-generated question, which added cognitive load and the on-device model reliably generated
poor questions. Tappable options remove typing and move the hardest judgment (what kind of help
is needed) to the user's tap, leaving generation a constrained, reliable task.

## 4. State Machine — superseded

Current state machine is defined by `flow_redesign_spec.md` §4–5. The original two-screen
Reflection/Clarification flow described here has been folded into one Reflection + Choice
screen, and "Save this step → Reminders" is replaced by **Save for later**
(`recommended_steps_spec.md`).

---

## 5. AI Contracts

### Stage 1 — Extraction

**Input:** raw brain dump string

**Output:**
```swift
@Generable
struct ExtractionResult {
    let isActionable: Bool
    let clarificationPrompt: String?   // non-nil when isActionable == false
    let goalSummary: String
    let blockers: [Blocker]
    let frictionSummary: String
}

@Generable
struct Blocker {
    let description: String
    let type: BlockerType
}

@Generable
enum BlockerType: String, Generable {
    case practical       // missing resources, skills, or information
    case informational   // unclear path, criteria, or decision
    case emotional       // fear, avoidance, overwhelm
}
```

**Prompt contract:**
- Always return 1–3 blockers when `isActionable == true`
- `clarificationPrompt` must be a single friendly sentence ending in "?"
- `goalSummary` must be one sentence
- `frictionSummary` must be one sentence
- Avoid therapy language, diagnosis, or judgment

---

### Stage 2 — Clarification Options

**Input:** `ExtractionResult`

**Output:**
```swift
@Generable
enum StuckMode: String {
    case reproduce  // user has tried fixes repeatedly with no success
    case narrow     // user doesn't know where to begin or what the cause is
    case clarify    // user feels overwhelmed or scattered
}

@Generable
struct ClarificationOption {
    let label: String       // short first-person phrase shown as a tappable button
    let mode: StuckMode     // internal — constrains Stage 3 generation
}

@Generable
struct ClarificationResult {
    let options: [ClarificationOption]  // always exactly 3, one per StuckMode
}
```

**Prompt contract:**
- Always return exactly 3 options, one for each `StuckMode`
- Each `label` must be a short first-person phrase specific to the user's situation
- Labels must be immediately recognizable — not abstract or generic
- Do not generate questions — generate phrases the user identifies with by tapping

---

### Stage 3 — Next Step Generation

**Input:** `ExtractionResult` + user-selected `StuckMode`

**Output:**
```swift
@Generable
struct NextStepResult {
    let nextStep: String      // activation step, action-first, specific to selected mode
    let fallbackStep: String  // smaller version — completable in under 5 minutes
}
```

**Prompt contract:**
- `nextStep` must be one sentence, action-first (e.g. "Write down...", "List...", "Open...")
- Step type is constrained by selected `StuckMode`:
  - `reproduce` → document or isolate conditions that cause the problem
  - `narrow` → list possibilities or reduce scope
  - `clarify` → identify the one question most needed
- `fallbackStep` must be even smaller — lowest possible activation energy
- No technical fixes, no debugging solutions, no domain-specific recommendations
- No multi-step plans, no vague advice, no therapy language

---

## 6. Data Model

### Draft (in-progress session)

```swift
// Persisted via AppStorage — survives app kill/relaunch
@AppStorage("draft_brain_dump") var draftBrainDump: String = ""
```

Draft is the only persistence of *in-progress* state in MVP. No completed-session
storage beyond the two items below.

### Saved steps (`RecommendedStepStore`)

Per the flow redesign, steps the user explicitly saves persist in a local
`RecommendedStepStore` surfaced in the **Saved** tab. (See `recommended_steps_spec.md`.)

### Lightweight session log (forward-compatible groundwork)

On each **resolved** session, append one flat record to an append-only log:

```swift
struct SessionLogEntry: Codable {
    let createdAt: Date
    let brainDumpSnippet: String   // short
    let chosenMode: StuckMode
    let blockerTypes: [BlockerType]
}
```

- **Deliberately dumb.** No `repeatSubjectKey`, no `threadID` threading, no aggregation,
  no surfaces, no paywall. A handful of fields written on resolve.
- **Why it ships in MVP anyway:** it accrues history silently (so the post-MVP
  personalization feature has fuel instead of a cold start) and lets us validate, from
  real data, whether users actually get stuck on *recurring* subjects — the assumption
  the entire Pro story depends on.
- The full personalization feature that builds on this log is **post-MVP** and specified
  in `pattern_detection_spec.md`. Do not build that machinery now.
- Requires making `StuckMode` and `BlockerType` `Codable` (they are not today).

---

## 7. Acceptance Criteria

### Core loop
- [ ] User can enter a brain dump and receive a reflection
- [ ] Reflection shows goal, blockers (with on-demand type disclosure), and friction summary
- [ ] User sees 3 tappable options and taps one to continue
- [ ] App produces one activation step appropriate to the selected mode
- [ ] "I'm still stuck" (first tap) reveals fallback step
- [ ] "I'm still stuck" (second tap) returns to S1 pre-filled with original brain dump
- [ ] Tapping "Start" clears the draft and returns to S1 fresh

### Draft persistence
- [ ] Brain dump text is restored after app is killed and relaunched
- [ ] Draft is cleared after tapping "Start" on S4
- [ ] Draft is pre-populated when returning to S1 via "I'm still stuck" (second tap)

### Save this step — superseded
The MVP `ShareLink`/Reminders save path is replaced by **Save for later**
(`recommended_steps_spec.md`), which stores the step in a local `RecommendedStepStore` and
updates the **Saved** tab badge.

### Edge cases
- [ ] Ineligible device shows S0 and blocks entry
- [ ] Low-confidence brain dump shows inline clarification prompt on S1
- [ ] Re-submission after clarification runs Stage 1 again cleanly
- [ ] Empty input disables the CTA button

### AI behavior
- [ ] Stage 1 always returns 1–3 blockers when `isActionable == true`
- [ ] Stage 2 always returns exactly 3 options, one per `StuckMode`
- [ ] Stage 3 output is one sentence, action-first, appropriate to selected mode
- [ ] Stage 3 output does not suggest technical fixes or domain-specific solutions
- [ ] No response exceeds readable length on screen

---

## 8. Out of Scope for MVP

- Session history (list, detail, try again) — **post-MVP**
- **Pattern detection / personalization (the "learns how you get stuck" Pro feature) —
  post-MVP.** Gated on observed retention + real subject recurrence in the lightweight
  session log (§6). Specified in `pattern_detection_spec.md`. The *only* part that ships
  in MVP is the dumb append-only log itself.
- **Paywall / StoreKit / IAP** — post-MVP. No purchase flow in the MVP.
- Cloud sync or multi-device
- Edit-and-regenerate (partial re-run)
- Team or sharing features
- Long-term planning or project tracking
- Deep coaching or therapy behavior
- Cloud AI fallback
- Onboarding flow beyond device eligibility check

---

## 9. What "Done" Means for MVP

The MVP is done when:
1. The full core loop works end-to-end on a qualifying device
2. Brain dump draft survives app kill and relaunch
3. "I'm still stuck" (second tap) returns to S1 pre-filled
4. Ineligible devices are handled gracefully
5. All acceptance criteria above are checked

---
