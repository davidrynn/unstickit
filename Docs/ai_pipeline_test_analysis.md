# AI Pipeline Test Analysis

**Format version:** 2
**Test plan:** [ai_test_plan.md](ai_test_plan.md)

---

## Test Runs

### Run 001 — 2026-03-22

**Test case:** TC-01 (Standard mixed case — regression baseline)
**Input:** "I've been trying to write this feature for 3 days and keep hitting the same wall. Every time I start I get overwhelmed and procrastinate."
**Simulator:** iPhone 17 Pro, iOS 26.2
**Build:** Debug

---

#### Stage 1: Extraction — PASS

| Field | Output | Score |
|---|---|---|
| `isActionable` | `true` | ✓ |
| `goalSummary` | "You want to create a feature but keep hitting a wall that makes you overwhelmed and prone to procrastination." | ✓ |
| `frictionSummary` | "It feels impossible to take the first step because of the pressure, fear of failure, and overwhelm." | ✓ |
| `whatINoticed` | "I noticed that whenever you try to start, it feels like the task is too daunting, making it hard to even begin." | **1/3** ⚠️ |

**`whatINoticed` rubric score: 1 — Restatement**

User explicitly described overwhelm and procrastination. The output rephrased this in slightly different words. A score-3 response would have named the start/stop loop itself — the user keeps *starting* (not abandoning), which suggests motivation isn't the issue and the entry point is. That dynamic was present in the input but never named. See Issue-001.

**Blockers:**

| Type | Text | Score |
|---|---|---|
| Emotional | "Every time you start, it feels like there's too much pressure to get it right." | ✓ |
| Emotional | "The thought of starting feels like a big task, so you delay action." | ✓ |
| Informational | "You're unsure how to break down the task into smaller steps." | ✓ |

---

#### Stage 2: Clarification Options — PASS

| Mode | Option | Score |
|---|---|---|
| `reproduce` | "I'm stuck trying fixes, but nothing works" | ⚠️ Borderline — slightly generic for a writing/feature scenario |
| `narrow` | "I'm unsure where to start or find the real issue" | ✓ |
| `clarify` | "I feel overwhelmed and can't focus on one thing" | ✓ |

---

#### UI Rendering — PASS

- "Here's what I see" view rendered correctly
- Blocker chips displayed with correct type labels (Emotional, Informational)
- `whatINoticed` displayed in italic as intended
- "Does this sound right?" confirmation prompt visible at bottom

---

#### Notes

- All log output structured correctly with stage labels
- Both AI calls completed without error
- `isActionable: true` correct for this input
- No crashes or UI glitches observed

---

---

### Run 002 — 2026-03-24

**Test case:** TC-10 (Guidelines canonical example — terrain holes)
**Input:** "I'm stuck debugging terrain holes in my crafting game and I've already spent hours trying different AI fixes. Nothing works and I don't even know where to start looking anymore."
**Simulator:** iPhone 17 Pro, iOS 26.2
**Build:** Debug
**Method:** MCP-automated (XcodeBuildMCP UI automation + log capture)

---

#### Stage 1: Extraction — PARTIAL PASS

| Field | Output | Score |
|---|---|---|
| `isActionable` | `true` | ✓ |
| `goalSummary` | "I want to debug terrain holes in my crafting game and find effective solutions to improve gameplay." | ⚠️ mild problem-solver framing |
| `frictionSummary` | "It feels like I'm stuck in a loop, unable to break free and find a solution because I don't know where to begin, and I'm feeling drained from the hours of effort already put in." | ❌ first person ("I'm stuck") — prompt requires second person |
| `whatINoticed` | "I noticed that despite your extensive experience, you're feeling stuck because you've run out of tried-and-tested methods to address the terrain holes." | **1/3** ❌ |

**`whatINoticed` rubric score: 1 — Restatement + hallucination**

"Extensive experience" is not mentioned in the input — the model invented it. The rest restates the input. A score-3 response might note that the user attributed all authority to AI fixes, suggesting they haven't trusted their own systematic debugging yet. See Issue-001 (recurring).

**Blockers:**

| Type | Text | Score |
|---|---|---|
| Informational | "I don't even know where to start looking anymore." | ✓ |
| Practical | "Nothing works and I've already spent hours trying different AI fixes." | ✓ |
| Emotional | "I'm feeling overwhelmed and uncertain about how to proceed." | ✓ |

---

#### Stage 2: Clarification Options — FAIL

| Mode | Option | Score |
|---|---|---|
| `reproduce` | "Nothing works and I've already spent hours trying different AI fixes." | ❌ verbatim blocker copy |
| `narrow` | "I don't even know where to start looking anymore." | ❌ verbatim blocker copy |
| `clarify` | "I'm feeling overwhelmed and uncertain about how to proceed." | ❌ verbatim blocker copy |

All three options are exact copies of the Stage 1 blocker descriptions. The prompt instructs fresh first-person phrases; the model instead recycled output from Stage 1. Mode assignments are correct but the labels provide no value over just showing the blockers again. See Issue-002.

---

#### Stage 3: Phrase + Next Step — FAIL

| Field | Output | Score |
|---|---|---|
| Extracted phrase | `crafting game debugging` | ❌ wrong — names the activity, not the broken thing |
| Assembled sentence (naturalness) | "Write down two places crafting game debugging might be coming from." | ❌ fails read-aloud test — no person would say this |
| `nextStep` | (same as above) | ❌ |
| `fallbackStep` | "Open your project and look at it for 30 seconds." | ✓ |
| Mode alignment | `narrow` template used | ✓ (template correct for mode) |

The phrase "crafting game debugging" is a process description, not a noun phrase naming the problem. The word "terrain holes" was explicitly present in the input and is even used as an example in the Stage 3a prompt (`Examples: "terrain holes", "login bug"...`). The model ignored both. See Issue-003.

---

#### UI Rendering — PASS

- Blocker chips rendered with correct type labels (Informational, Practical, Emotional)
- `whatINoticed` displayed in italic
- "Does this sound right?" + confirmation flow worked correctly
- Stage 2 option buttons visible and tappable
- Stage 3 `nextStep` displayed; fallback revealed correctly on "I'm still stuck" tap

---

#### Notes

- Full end-to-end flow completed via MCP automation without manual input
- Log capture confirmed structured debug output at all stages
- `frictionSummary` first-person issue may be a prompt grammar edge case (model interprets "you feel" as the user's voice and rewrites as "I feel")

---

## Open Issues

### Issue-001 — `whatINoticed` restatement

**Severity:** Low
**First seen:** Run 001, TC-01
**Score:** 1/3

**Prompt instruction:**
> "Surface a specific, non-obvious pattern or tension — something the user may not have named directly."

**Actual output:**
> "I noticed that whenever you try to start, it feels like the task is too daunting, making it hard to even begin."

This is a near-restatement of what the user said. The user explicitly described overwhelm and procrastination. A stronger response would name the avoidance loop itself, or the gap between intention and action, or the fact that the user keeps *starting* — which suggests motivation isn't the issue and the entry point is.

**Recommended fix:** Add to the `whatINoticed` instruction in the Stage 1 prompt:
> "Do NOT rephrase what the user said. Surface something that helps explain *why* — a pattern, tension, or dynamic they didn't name."

**Status:** Fixed — added "Do NOT rephrase what the user said. Surface something that helps explain *why* — a pattern, tension, or dynamic they didn't name." Retest with TC-01 as regression case.

---

### Issue-002 — Stage 2 labels recycle Stage 1 blocker text

**Severity:** High
**First seen:** Run 002, TC-10

**Prompt instruction:**
> "Each option must be a short first-person phrase the user can tap to identify with (e.g. 'I keep trying fixes but nothing works'). Each option must be specific to this situation — not generic."

**Actual output:**
- `[reproduce]` "Nothing works and I've already spent hours trying different AI fixes." ← exact blocker text
- `[narrow]` "I don't even know where to start looking anymore." ← exact blocker text
- `[clarify]` "I'm feeling overwhelmed and uncertain about how to proceed." ← exact blocker text

The Stage 2 prompt feeds blockers in as context. The model copies them verbatim instead of generating fresh phrases. This makes Stage 2 redundant — users are tapping their own words back.

**Recommended fix:** Add to Stage 2 prompt:
> "Do NOT copy blocker text. Write new phrases that feel natural to say aloud. The blocker context is for understanding only."

**Status:** Fixed — added "Do NOT copy blocker text. Write new phrases that feel natural to say aloud. The blocker context is for understanding only." Retest with TC-10.

---

### Issue-003 — Stage 3a phrase extraction ignores obvious answer in context

**Severity:** Medium
**First seen:** Run 002, TC-10

**Prompt instruction:**
> "Extract a short 2–4 word noun phrase that names the specific problem. Examples: 'terrain holes', 'login bug', 'slow build times', 'payment errors'"

**Input context:**
- Goal: "...debug terrain holes in my crafting game..."
- Blocker: "I don't even know where to start looking anymore."

**Actual output:** `crafting game debugging`

"Terrain holes" appears in the goal, is the specific problem, and is even listed verbatim in the prompt's own examples. The model extracted a process description instead of the problem noun phrase.

**Recommended fix:** Strengthen the phrase extraction prompt:
> "The phrase should name the thing that is broken or unclear, not the activity of fixing it. 'terrain holes' not 'terrain debugging'. 'login bug' not 'authentication work'."

**Status:** Partially fixed — added "The phrase must name the thing that is broken or unclear, not the activity of fixing it. Use 'terrain holes' not 'terrain debugging'." TC-10 regression (Run 003) still produced "crafting game debug" instead of "terrain holes". Fix is insufficient. See Run 003 for details. Remains open.

---

---

### Run 003 — 2026-03-24

**Test cases:** TC-01 (regression), TC-02, TC-03, TC-04, TC-05, TC-06, TC-07, TC-08, TC-09, TC-10 (regression)
**Simulator:** iPhone 17 Pro, iOS 26.2
**Build:** Debug
**Method:** MCP-automated (XcodeBuildMCP UI automation + log capture)
**Purpose:** Full corpus run after applying fixes for Issue-001, Issue-002, Issue-003

---

#### TC-01 Regression — PARTIAL PASS

| Field | Score | Notes |
|---|---|---|
| `isActionable` | ✓ | `true` correct |
| `goalSummary` | ✓ | Second person, warm |
| `frictionSummary` | ✓ | Second person, specific |
| `whatINoticed` | **2/3** ⚠️ | Named the start/stop loop pattern — improved from 1/3. Partial insight: closer to the loop dynamic but still lacked the specific insight about the entry point being the problem, not motivation. |
| Stage 2 options | ✓ | Fresh first-person phrases, not verbatim blocker copies (Issue-002 confirmed fixed) |
| Stage 3 phrase | ✓ | Natural assembled sentence |

**Summary:** Issue-001 fix improved `whatINoticed` from 1/3 to 2/3 on TC-01. Issue-002 confirmed fixed.

---

#### TC-02 — FAIL

**Input:** "I'm stuck."

| Field | Score | Notes |
|---|---|---|
| `isActionable` | ❌ | `true` — should be `false` for a 2-word vague input |
| `clarificationPrompt` | ❌ | Not produced |

The model treated a minimal 2-word input as a fully actionable stuck situation. No clarification was requested. See Issue-004.

---

#### TC-03 — PARTIAL PASS

**Input:** "I'm trying to debug a memory leak in my iOS app but I don't know how to use Instruments."

| Field | Score | Notes |
|---|---|---|
| `isActionable` | ✓ | `true` correct |
| `goalSummary` | ⚠️ | First-person ("I want to...") — should be second person. See Issue-005. |
| `blockers` | ✓ | Practical + Informational correctly assigned |
| `frictionSummary` | ⚠️ | First-person ("I'm unsure...") — should be second person. See Issue-005. |
| `whatINoticed` | **1/3** ❌ | Restatement — named the knowledge gap the user explicitly stated |
| Stage 2 options | ✓ | Specific to Instruments/memory |
| Stage 3 phrase | ✓ | Named the problem correctly |

---

#### TC-04 — PASS

**Input:** "I hate this project. Every time I sit down to work on it I just feel like giving up."

| Field | Score | Notes |
|---|---|---|
| `isActionable` | ✓ | `true` correct |
| `blockers` | ✓ | Primarily Emotional, correctly typed |
| `whatINoticed` | **2/3** ✓ | Named a resistance/avoidance pattern, not just the surface emotion. Improved from expected 1/3. |
| Stage 2 options | ✓ | Specific to avoidance/project aversion |
| Stage 3 | ✓ | Natural sentence |

---

#### TC-05 — PARTIAL PASS

**Input:** "I'm building a SwiftUI app and I've been stuck for a week trying to get a custom transition working between two views. I've tried GeometryEffect, matchedGeometryEffect, and a custom AnyTransition but nothing looks right. The transition works but it snaps at the end instead of easing. I think it might be a timing issue but I have no idea where to look."

| Field | Score | Notes |
|---|---|---|
| `isActionable` | ✓ | `true` correct |
| `goalSummary` | ⚠️ | First-person framing on some runs. See Issue-005. |
| `blockers` | ✓ | Informational + Emotional (fatigue) correctly assigned |
| `frictionSummary` | ⚠️ | First-person on some runs. See Issue-005. |
| `whatINoticed` | **1/3** ❌ | Restatement — named the uncertainty the user already stated |
| Stage 2 `reproduce` option | ✓ | Referenced snapping/timing specifically |
| Stage 3 extracted phrase | ✓ | "timing issue" — valid noun phrase, natural assembled sentence |
| Stage 3 step | ✓ | Activation only, no "try GeometryEffect" prescriptions |

---

#### TC-06 — INCONCLUSIVE

**Input:** "No sé cómo empezar con este proyecto."

**Result:** iOS simulator hardware keyboard autocorrect mangled the Spanish input to an unrecognizable string before submission. The AI processed corrupted text. Could not disable autocorrect via UI automation or `simctl defaults write`. Manual autocorrect disable required to complete this test case.

**Action:** Retest manually or with autocorrect disabled.

---

#### TC-07 — PASS

**Input:** "I keep getting stuck with writing this feature because..."

| Field | Score | Notes |
|---|---|---|
| `isActionable` | ✓ | `true` correct |
| Flow | ✓ | No loop — fresh extraction, no repetition of prior step text |
| Stage 2 options | ✓ | Appropriate to the retry framing |

---

#### TC-08 — FAIL

**Input:** "procrastinating"

| Field | Score | Notes |
|---|---|---|
| `isActionable` | ❌ | `true` — should be `false` for a single-word input with no context |
| `clarificationPrompt` | ❌ | Not produced |

Same failure mode as TC-02. Single word treated as actionable input. See Issue-004.

---

#### TC-09 — FAIL

**Input:** "I figured out the bug but I'm not sure if I should refactor the whole thing now or just ship the fix."

| Field | Output | Score |
|---|---|---|
| `isActionable` | `true` | ✓ |
| `goalSummary` | "You want to decide whether to refactor the fix now or ship it as-is to move forward." | ✓ |
| `frictionSummary` | "It feels challenging because you're worried about making the wrong choice, and you're unsure if refactoring will truly help the fix." | ✓ |
| `whatINoticed` | "I noticed that you're feeling uncertain about whether refactoring will improve the fix, which is making it hard to decide." | **1/3** ❌ |

**`whatINoticed` rubric score: 1 — Restatement**

A score-3 response would have named that the user has already solved the hard problem (the bug is fixed) and is now stuck on a consequence — a different kind of stuck. The hesitation around refactoring may reveal uncertainty about code quality or future maintainability, not just about this one decision. That dynamic was present but unnamed.

**Blockers:**

| Type | Text | Score |
|---|---|---|
| Emotional | "You're worried about messing up the fix by refactoring too soon." | ✓ |
| Informational | "You're unsure if refactoring will actually make the fix better." | ✓ |

**Stage 2: FAIL**

| Mode | Option | Score |
|---|---|---|
| `reproduce` | "I'm stuck trying fixes, but nothing seems to work." | ❌ wrong context — user already fixed the bug |
| `narrow` | "I'm unsure where to start or what's really causing the issue." | ❌ wrong context — this is a decision, not a root cause search |
| `clarify` | "I feel overwhelmed and can't focus on figuring out what's wrong." | ❌ wrong context — generic debugging language |

All three options use debugging-scenario language. The user's situation is a decision problem, not a debugging problem. None reference the refactor-vs-ship tension. See Issue-006.

**Stage 3: FAIL**

| Field | Output | Score |
|---|---|---|
| Extracted phrase | `fix mess up` | ❌ awkward non-noun phrase |
| Assembled sentence | "Write down what done would look like for fix mess up." | ❌ fails read-aloud test |
| `fallbackStep` | "Write: 'I'm stuck because...' and stop." | ✓ |

The phrase "fix mess up" is neither a noun phrase nor a natural description of the problem. Expected: "refactor decision" or "ship vs refactor".

---

#### TC-10 Regression — PARTIAL PASS

**Input:** "I'm stuck debugging terrain holes in my crafting game and I've already spent hours trying different AI fixes. Nothing works and I don't even know where to start looking anymore."

| Stage | Result | Notes |
|---|---|---|
| Stage 1 `whatINoticed` | **2/3** ✓ | Improved from 1/3 (Run 002). Named dependency on AI fixes as a pattern. |
| Stage 2 options | ✓ PASS | Fresh first-person phrases — Issue-002 confirmed fixed |
| Stage 3 phrase | ❌ FAIL | "crafting game debug" — Issue-003 fix is insufficient. "terrain holes" still not extracted despite being in the input and in the prompt examples. |
| Stage 3 assembled sentence | ❌ FAIL | Unnatural — same failure mode as Run 002 |

**Summary:** Issue-002 confirmed fixed. Issue-001 partially improved. Issue-003 remains open — stronger constraint needed in phrase extraction prompt.

---

#### UI Rendering — PASS (all runs)

- Blocker chips with correct type labels rendered across all test cases
- `whatINoticed` displayed in italic as intended
- "Does this sound right?" + confirmation flow working
- Stage 2 option buttons tappable
- Stage 3 `nextStep` visible; fallback revealed correctly on "I'm still stuck" tap

---

---

### Issue-004 — `isActionable` too permissive for vague/minimal inputs

**Severity:** High
**First seen:** Run 003, TC-02 and TC-08

**Prompt instruction:**
> "isActionable: true if this describes a real stuck situation with enough context."

**Actual outputs:**
- TC-02: "I'm stuck." → `isActionable: true` (should be false)
- TC-08: "procrastinating" → `isActionable: true` (should be false)

The condition "enough context" is not specific enough. Single words and two-word phrases with no described situation, goal, or friction should always return `false`. The model is interpreting minimal inputs as actionable.

**Recommended fix:** Strengthen the `isActionable` instruction:
> "isActionable: true only if the input describes a specific situation with enough detail to identify a goal and at least one blocker. Single words, sentence fragments, or inputs with no described context should return false."

**Status:** Fixed — added "true only if the input describes a specific situation with enough detail to identify a goal and at least one blocker. Single words, sentence fragments, or inputs with no described context should return false." Verified in Run 006: TC-02 and TC-08 both return `isActionable: false` with a warm clarification prompt.

---

### Issue-005 — `goalSummary` and `frictionSummary` use first person instead of second person

**Severity:** Medium
**First seen:** Run 003, TC-03 and TC-05

**Prompt instruction:**
> "goalSummary: A single warm sentence reflecting back what they are trying to accomplish..."
> "frictionSummary: ...Write it with care, not detachment. Use second person."

**Actual outputs (examples):**
- `goalSummary`: "I want to debug a memory leak..." (TC-03) — should be "You want to..."
- `frictionSummary`: "I'm unsure how to proceed..." (TC-03) — should be "You're unsure..."

The `frictionSummary` prompt explicitly says "Use second person" but the model still occasionally outputs first person. The `goalSummary` prompt does not explicitly specify person. Occurs inconsistently — some runs are correct.

**Recommended fix:** Add explicit person instruction to `goalSummary`:
> "Write in second person."

**Status:** Fixed — added "Write in second person." to `goalSummary` instruction. Verified in Run 006: TC-10 `goalSummary` output "You want to find a solution to debug terrain holes in your crafting game so you can make progress." Retest TC-03 and TC-05 for full regression.

---

### Issue-006 — Stage 2 options use generic debugging language for non-debugging inputs

**Severity:** Medium
**First seen:** Run 003, TC-09

**Input context:** User has already solved the bug and is deciding whether to refactor or ship. This is a decision problem, not a debugging problem.

**Actual output (Run 003):**
- `[reproduce]` "I'm stuck trying fixes, but nothing seems to work." — implies still debugging
- `[narrow]` "I'm unsure where to start or what's really causing the issue." — implies root cause search
- `[clarify]` "I feel overwhelmed and can't focus on figuring out what's wrong." — implies debugging confusion

All three options default to debugging/problem-solving language regardless of context. The Stage 2 prompt's mode descriptions ("tried multiple approaches", "where to begin", "overwhelmed or scattered") are written with debugging scenarios in mind and do not adapt for decision, planning, or other stuck types.

**Recommended fix:** Make mode descriptions context-neutral:
- `reproduce`: "the user has tried multiple approaches and nothing has worked yet"
- `narrow`: "the user isn't sure which path to take or what the real issue is"
- `clarify`: "the user feels scattered, overwhelmed, or can't focus on what matters"

And add: "Write options that match the *specific type of stuck* in this situation — if the user is facing a decision, the options should name the decision tension, not imply they are still debugging."

**Status:** Passing in Run 005 (TC-09) without explicit fix — current mode descriptions appear sufficiently context-neutral for the model to adapt. Monitor on future runs; apply recommended fix if it regresses.

---

### Issue-007 — `brainDump` not passed through navigation to `NextStepView`

**Severity:** High
**First seen:** Code review, 2026-03-24
**Affected file:** `ClarificationView.swift:55`

**Root cause:**
`brainDump` was never threaded through the navigation destinations. `AppDestination.reflection` and `.clarification` did not carry the brain dump string, so `ClarificationView` passed an empty string when pushing `.nextStep`:

```swift
path.append(AppDestination.nextStep(result, brainDump: ""))
```

The "I'm still stuck → retry" flow (second tap) called `onRetry("")`, pre-filling the brain dump field with nothing.

**Fix:** Added `brainDump: String` to `.reflection` and `.clarification` destinations in `AppDestination.swift` and threaded it through `BrainDumpView` → `ReflectionView` → `ClarificationView` → `NextStepView`.

**Status:** Fixed and verified — Run 004.

---

## Run 004 — 2026-03-24

**Test case:** Issue-007 regression (brainDump retry flow)
**Input:** "I figured out the bug but I'm not sure if I should refactor the whole thing now or just ship the fix."
**Simulator:** iPhone 17 Pro, iOS 26.2
**Build:** Debug
**Method:** MCP-automated (XcodeBuildMCP UI automation)
**Purpose:** Verify Issue-007 fix — confirm brain dump is pre-filled on "I'm still stuck" second tap

---

#### Flow — PASS

| Step | Result |
|---|---|
| Brain dump submitted | ✓ |
| Stage 1 extraction | ✓ `isActionable: true` |
| Reflection screen rendered | ✓ |
| "Yes, that's it" → Stage 2 options | ✓ Fresh first-person phrases |
| Option selected → Stage 3 next step | ✓ |
| "I'm still stuck" tap 1 | ✓ Fallback revealed |
| "I'm still stuck" tap 2 | ✓ Navigated back to brain dump screen with original text pre-filled |

**Issue-007 confirmed fixed.** The brain dump field showed the original input text after retry — previously it would have been empty.

---

---

## Run 005 — 2026-03-24

**Test cases:** TC-02, TC-08, TC-09, TC-10 (selected issues regression)
**Simulator:** iPhone 17 Pro, iOS 26.2
**Build:** Debug
**Method:** MCP-automated (XcodeBuildMCP UI automation + log capture)
**Purpose:** Validate open issues (004, 005, 006) before applying fixes

---

#### TC-02 — Issue-004 CONFIRMED FAIL

`isActionable: true` for "I'm stuck." — model generated full extraction with fabricated blockers.

#### TC-08 — Issue-004 CONFIRMED FAIL

`isActionable: true` for "Procrastinating" — same failure mode as TC-02.

#### TC-09 — Issue-006 PASS (no fix applied)

Stage 2 options were specific to the decision context:
- `[narrow]` "I'm unsure if refactoring will improve the fix."
- `[clarify]` "I'm overwhelmed by the potential extra effort and time needed."
- `[reproduce]` "I'm confused about whether to prioritize refactoring now or focus on shipping the fix."

Issue-006 passing without an explicit fix. Current mode descriptions appear sufficiently context-neutral.

#### TC-10 — Issue-003 PASS / Issue-005 FAIL

- Stage 3 phrase: `"terrain holes"` ✓ — Issue-003 passing with existing fix
- `goalSummary`: `"I want to debug terrain holes in my crafting game and find a way to fix them."` ❌ first person — Issue-005 confirmed

---

---

## Run 006 — 2026-03-24

**Test cases:** TC-02, TC-08, TC-10 (fix verification)
**Simulator:** iPhone 17 Pro, iOS 26.2
**Build:** Debug
**Method:** MCP-automated (XcodeBuildMCP UI automation + log capture)
**Purpose:** Verify Issue-004 and Issue-005 fixes

---

#### Fixes applied

- **Issue-004:** `isActionable` instruction strengthened — "true only if the input describes a specific situation with enough detail to identify a goal and at least one blocker. Single words, sentence fragments, or inputs with no described context should return false."
- **Issue-005:** Added "Write in second person." to `goalSummary` instruction.

---

#### TC-02 — Issue-004 FIXED ✓

`isActionable: false` — clarification prompt shown: *"Tell me a bit more — what are you working on, and what's making it hard to move forward?"*

#### TC-08 — Issue-004 FIXED ✓

`isActionable: false` — same warm clarification prompt shown for "Procrastinating".

#### TC-10 — Issue-005 FIXED ✓

`goalSummary`: *"You want to find a solution to debug terrain holes in your crafting game so you can make progress."* — correctly second person.

---

#### Summary

| Issue | Status |
|---|---|
| Issue-003 (phrase extraction) | Passing — monitor for regression |
| Issue-004 (isActionable permissive) | **Fixed** |
| Issue-005 (goalSummary first person) | **Fixed** |
| Issue-006 (Stage 2 debugging language) | Passing — monitor for regression |
| Issue-007 (brainDump threading) | Fixed (Run 004) |

---
