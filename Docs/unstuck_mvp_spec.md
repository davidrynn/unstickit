# Unstuck — MVP Spec

## Status
**Draft** — derived from Plan Iteration 3 + resolved open questions

---

## 1. Product Summary

**App name:** Unstuck
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

## 3. Screens

### S0 — Apple Intelligence Required
Shown when device does not meet requirements.

**Content:**
- Title: "Unstuck requires Apple Intelligence"
- Body: brief explanation of the requirement
- Link to Apple's Apple Intelligence settings (deep link if available)

**No navigation forward from this screen.**

---

### S1 — Brain Dump
The entry point and root of the app.

**Content:**
- Title: **Unstuck**
- Prompt: **What are you stuck on?**
- Large multiline text input (autosaved to draft on every change)
- CTA button: **Help me think this through**
- Inline clarification area (hidden by default — shown if `isActionable == false`)

**States:**
- **Default** — empty input, button disabled
- **Has input** — button enabled
- **Loading** — button shows spinner, input disabled (Stage 1 running)
- **Needs clarification** — `clarificationPrompt` shown inline below input, input re-enabled

**Draft persistence:**
- Brain dump text is autosaved to `AppStorage` on every keystroke
- On launch, if a saved draft exists, the text input is pre-populated
- Draft is cleared when the user taps "Start" on S4 (session complete) or manually clears the input

**Transitions:**
- Tap CTA → run Stage 1
  - `isActionable == true` → S2
  - `isActionable == false` → stay on S1, show `clarificationPrompt` inline

---

### S2 — Reflection
Shows what the AI extracted from the brain dump.

**Content:**
- Section: **Your goal** — `goalSummary`
- Section: **What might be blocking you** — list of `blockers`
  - Each blocker shows `description`
  - Disclosure chevron reveals `type` label on tap (on demand)
- Section: **What might be making this hard** — `frictionSummary`
- Loading indicator while Stage 2 runs (options loading)

**States:**
- **Loading** — reflection content visible, options loading
- **Options ready** → auto-advance to S3

**Transitions:**
- After Stage 2 completes → S3

---

### S3 — Clarification
Presents 3 tappable options describing how the user feels stuck. The user taps one — no typing required.

**Content:**
- Prompt: **Which feels most true right now?**
- 3 tappable option buttons (`ClarificationResult.options[].label`)
- Each button shows a short first-person phrase specific to the user's situation

**States:**
- **Default** — 3 options visible, ready to tap
- **Loading** — after tap, Stage 3 running (buttons disabled)

**Why tappable options instead of typed answers:**
Early versions asked the user to type a response to an AI-generated question. This added
cognitive load — exactly what stuck users have least of — and the on-device model reliably
generated poor questions. Tappable options remove typing and move the hardest judgment
(what kind of help is needed) to the user's tap, leaving Stage 3 with a constrained,
reliable generation task.

**Transitions:**
- Tap any option → run Stage 3 with selected `StuckMode` → S4

---

### S4 — Next Step
The primary output screen.

**Content:**
- Label: **Your next step**
- `nextStep` text (prominent)
- CTA button: **Start**
- Secondary button: **I'm still stuck**
- Fallback area (hidden by default)

**States:**
- **Default** — shows `nextStep`, "Start", "I'm still stuck"
- **Fallback revealed** — shows `nextStep` + `fallbackStep`, "Start", "I'm still stuck"
- **Give up** — second tap of "I'm still stuck" clears draft and returns to S1

**Transitions:**
- Tap "Start" → clear draft → S1 (fresh)
- Tap "I'm still stuck" (first time) → reveal `fallbackStep` inline
- Tap "I'm still stuck" (second time) → clear draft → S1 (pre-fill brain dump for retry)
- Tap "Start" after fallback shown → clear draft → S1 (fresh)

---

## 4. State Machine

| Screen | Action | Next State | Notes |
|--------|--------|------------|-------|
| Launch | Device ineligible | S0 | Block entry |
| Launch | Device eligible | S1 | Restore draft if present |
| S1 | Tap CTA | S1 loading | Run Stage 1 |
| S1 loading | `isActionable == false` | S1 needs clarification | Show `clarificationPrompt` inline |
| S1 needs clarification | User adds more + resubmits | S1 loading | Re-run Stage 1 |
| S1 loading | `isActionable == true` | S2 | Auto-advance |
| S2 | Stage 2 complete | S3 | Auto-advance |
| S3 | Tap option | S3 loading | Run Stage 3 with selected StuckMode |
| S3 loading | Stage 3 complete | S4 | |
| S4 default | Tap "Start" | S1 fresh | Clear draft |
| S4 default | Tap "I'm still stuck" (1st) | S4 fallback | Reveal fallbackStep |
| S4 fallback | Tap "Start" | S1 fresh | Clear draft |
| S4 fallback | Tap "I'm still stuck" (2nd) | S1 pre-filled | Pre-fill brain dump, clear draft |

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

Draft is the only persistence in MVP. No completed session storage.

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
- Cloud sync or multi-device
- Edit-and-regenerate (partial re-run)
- Team or sharing features
- Notifications or reminders
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
