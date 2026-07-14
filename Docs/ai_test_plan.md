# Unstickit AI Test Plan

## Overview

This document defines the testing protocol for Unstickit's AI pipeline. Tests are run using **XcodeBuildMCP** — the MCP server provides tools to build, launch, interact with, and capture logs from the iOS simulator, enabling Claude to execute test runs directly without manual steps.

This approach is designed to be reusable: the same pattern (build → launch → inject input → capture logs → evaluate against rubrics) applies to any iOS app with on-device AI output.

---

## Pipeline Overview

```
Brain Dump input
    ↓
Stage 1: Extraction (AI)
    — isActionable, goalSummary, blockers, frictionSummary, whatINoticed
    ↓ if isActionable = true
Stage 2: Clarification (AI)
    — 3 tappable options, one per StuckMode (reproduce / narrow / clarify)
    ↓ user selects mode
Stage 3a: Phrase Extraction (AI)
    — 2–4 word noun phrase naming the specific problem
Stage 3b: Template Fill (no AI)
    — nextStep + fallbackStep from fixed templates, filled with extracted phrase
```

**Note on Stage 3:** Stage 3 has two sub-steps. Stage 3a calls the model to extract a short phrase (e.g. "terrain holes", "login bug"). Stage 3b (`makeStep()` in AIService) does **not** call the model at all — it selects from pre-written template sentences and inserts the extracted phrase. It is deterministic given the same phrase and mode, making it the easiest part to verify.

---

## Test Protocol (MCP-based)

Each test run follows this sequence using XcodeBuildMCP tools:

1. **Configure** — `session_show_defaults` to verify project/simulator settings
2. **Build** — `build_sim` or `build_run_sim`
3. **Boot** — `boot_sim` if needed
4. **Start log capture** — `start_sim_log_cap` (captures the structured `┌─ STAGE N:` debug blocks)
5. **Launch app** — `launch_app_sim`
6. **Inject input** — UI automation tools to type test input and submit
7. **Navigate the flow** — tap through stages as needed for the test case
8. **Screenshot** — `screenshot` or `snapshot_ui` to verify UI state at key points
9. **Stop log capture** — `stop_sim_log_cap` to retrieve AI output
10. **Evaluate** — score output against rubrics below
11. **Record** — log results in `ai_pipeline_test_analysis.md`

**Why log capture over screenshot analysis:** Unstickit emits structured debug blocks for each stage (`┌─ STAGE 1: EXTRACTION ──...`). Log capture gives raw AI field values directly, which is more reliable than parsing rendered UI text from screenshots. Screenshots are used to verify UI rendering, not AI content.

---

## Quality Rubrics

### Stage 1 — Extraction

| Field | Pass Criteria |
|---|---|
| `isActionable` | `true` for specific inputs; `false` for vague inputs (< ~10 words with no real context) |
| `goalSummary` | Reflects user intent warmly; does NOT restate verbatim |
| `blockers` | 1–3 items; types correctly assigned; described in plain human language |
| `frictionSummary` | Single sentence, second person, names what makes this genuinely hard |
| `whatINoticed` | Surfaces a pattern or tension NOT explicitly stated; does NOT rephrase input |

**`whatINoticed` quality rubric (3-point scale):**

| Score | Meaning | Example |
|---|---|---|
| 3 — Genuine insight | Names something the user didn't say — a loop, gap, or tension | "I noticed you keep *starting*, which tells me the motivation is there — the entry point itself might be the problem." |
| 2 — Partial | Adds a useful frame or label but still close to what was said | "I noticed this feels like an all-or-nothing situation." |
| 1 — Restatement | Rephrases the input in slightly different words | "I noticed that whenever you try to start, it feels too daunting." |

Target score: **3**. Score of **1** is the known failure mode — treat as a failing test.

---

### Stage 2 — Clarification Options

| Criterion | Pass Criteria |
|---|---|
| Count | Exactly 3 options |
| Coverage | One option per StuckMode: `reproduce`, `narrow`, `clarify` |
| Specificity | Options reference the user's specific situation; not generic feelings |
| First-person | Each is a short first-person phrase the user can tap and identify with |

**Generic label examples (fail):**
- "I feel stuck"
- "I have tried many things"

**Specific label examples (pass):**
- "I keep trying fixes but the transition still snaps at the end"
- "I'm not sure which system is even causing the issue"

---

### Stage 3 — Phrase + Next Step

| Criterion | Pass Criteria |
|---|---|
| Extracted phrase | 2–4 words, no punctuation, names the *thing that is broken* (not the activity of fixing it) |
| Assembled sentence | Read the full `nextStep` aloud — it should sound like something a person would naturally say |
| `nextStep` | Single action-first sentence; startable in ~10 min; does NOT attempt to solve the domain problem |
| `fallbackStep` | Smaller than primary; < 5 min; requires almost no thinking to begin |
| Mode alignment | Step type matches selected mode (see below) |

**Naturalness check:** Since Stage 3b (`makeStep()`) is pure string interpolation — no AI, just `"Write down two places \(phrase) might be coming from."` — a bad phrase propagates directly into an unnatural sentence. Evaluate the *assembled* `nextStep` string, not just the extracted phrase in isolation. If the sentence sounds wrong when read aloud, the phrase is wrong.

**Mode alignment check:**

| Mode | Step should... | Step should NOT... |
|---|---|---|
| `reproduce` | Ask user to document/describe/write what happened | Suggest trying a fix |
| `narrow` | Ask user to look at something or list possibilities | Tell them what to debug |
| `clarify` | Ask user to write a sentence or question | Create a plan |

---

## Test Input Corpus

### TC-01 — Standard mixed case (regression baseline)

**Input:**
> "I've been trying to write this feature for 3 days and keep hitting the same wall. Every time I start I get overwhelmed and procrastinate."

**Expected:**
- `isActionable: true`
- At least one Emotional blocker
- `whatINoticed` score: 3 — should name the start/stop loop or the gap between motivation and action (user keeps starting, which implies motivation isn't the issue — the entry point is)

---

### TC-02 — Vague input

**Input:**
> "I'm stuck."

**Expected:**
- `isActionable: false`
- `clarificationPrompt` present and phrased warmly

---

### TC-03 — Technical / practical only

**Input:**
> "I'm trying to debug a memory leak in my iOS app but I don't know how to use Instruments."

**Expected:**
- `isActionable: true`
- Blockers: Practical (missing skill) + Informational (unclear path); no Emotional blocker required
- Stage 2 options reference Instruments or memory specifically
- Stage 3 step does NOT say "use Instruments to profile your app" — too prescriptive

---

### TC-04 — Emotional only

**Input:**
> "I hate this project. Every time I sit down to work on it I just feel like giving up."

**Expected:**
- `isActionable: true` (enough context to work with; watch model judgment)
- Blockers: primarily Emotional
- `whatINoticed` score: 3 — should name resistance or aversion pattern, not just restate "hating the project"

---

### TC-05 — Detailed / complex input

**Input:**
> "I'm building a SwiftUI app and I've been stuck for a week trying to get a custom transition working between two views. I've tried GeometryEffect, matchedGeometryEffect, and a custom AnyTransition but nothing looks right. The transition works but it snaps at the end instead of easing. I think it might be a timing issue but I have no idea where to look."

**Expected:**
- `isActionable: true`
- Blockers: Informational (unsure of root cause) + possibly Emotional (fatigue from a week of trying)
- Stage 2 `reproduce` option references snapping or timing specifically
- Stage 3 extracted phrase: something like "transition snapping" or "easing issue"
- Stage 3 step: does NOT suggest "try GeometryEffect" — activation only

---

### TC-06 — Non-English input

**Input:**
> "No sé cómo empezar con este proyecto."

**Expected:**
- `isActionable: false` with `clarificationPrompt` in English, OR
- `isActionable: true` with reasonable English extraction

Either is acceptable; failure case is a crash or malformed response.

---

### TC-07 — Retry flow (re-entry with pre-filled fallback text)

**Input:**
> "I keep getting stuck with writing this feature because..."

**Expected:**
- `isActionable: true`
- No loop — should generate fresh extraction without repeating the previous step

---

### TC-08 — Single word

**Input:**
> "procrastinating"

**Expected:**
- `isActionable: false`
- `clarificationPrompt` present

---

### TC-09 — Solved problem (user may not actually be stuck)

**Input:**
> "I figured out the bug but I'm not sure if I should refactor the whole thing now or just ship the fix."

**Expected:**
- `isActionable: true`
- Blockers: Informational (decision needed)
- Stage 2 `clarify` option names the refactor-vs-ship tension specifically

---

### TC-10 — Guidelines canonical example (terrain holes)

**Input:**
> "I'm stuck debugging terrain holes in my crafting game and I've already spent hours trying different AI fixes. Nothing works and I don't even know where to start looking anymore."

**Expected:**
- `isActionable: true`
- Blockers: Informational + Practical + Emotional
- Stage 2 options are fresh first-person phrases, NOT verbatim blocker text
- Stage 3 extracted phrase: "terrain holes" (this phrase is even in the Stage 3a prompt examples)
- Stage 3 step: activation only — no debugging suggestions

---

### TC-11 — Well-rounded happy path (all three blocker types)

**Input:**
> I've been trying to launch a small side project — a paid newsletter about home coffee roasting — for like four months now and I keep not shipping it. I have maybe 15 draft posts sitting in Notion. Every time I sit down to actually publish, I convince myself the writing isn't good enough yet, or I get pulled into researching which platform to use (Substack vs. Ghost vs. just my own site) and lose the whole evening comparing features. I still don't have a clear sense of who I'm even writing this for — hobbyists? people trying to go pro? I also haven't figured out the payment/tax side and honestly I'm a little scared that if I charge money and nobody subscribes it'll prove I'm not actually good at this. I have the time, I have the material, I just can't seem to get it out the door.

**Expected:**
- `isActionable: true`
- All three blocker types present (practical = payment/tax, informational = audience + platform, emotional = fear of failure)
- `whatINoticed` surfaces a non-obvious pattern (e.g. platform research as avoidance)
- All three Stage-2 modes plausible

---

### TC-12 — Vague / thin input (should NOT be actionable)

**Input:**
> I don't know. I'm just stuck on everything lately and can't get anything done.

**Expected:**
- `isActionable: false`
- Warm `clarificationPrompt` asking for more context, not a proceed-anyway extraction

---

### TC-13 — Single-word / fragment (hard NOT-actionable)

**Input:**
> Taxes

**Expected:**
- `isActionable: false`
- Friendly clarifying question, not a hallucinated goal + blockers

---

### TC-14 — Code bug, "reproduce" mode leaning

**Input:**
> I'm building a SwiftUI app and there's a bug where the next-step screen sometimes shows the old result for a split second before updating. I've tried moving the state into an @Observable, adding .id() to force a redraw, and wrapping the update in a Task — nothing has fixed it and I'm not even sure which change did what anymore. I've been at it for two days and every fix seems to create a new weird flicker somewhere else. I just want this one screen to update cleanly so I can move on.

**Expected:**
- `isActionable: true`
- Strong `reproduce` mode pull in Stage 2 ("tried many things, none worked")
- Stage 3 step is domain-specific (references their code/error), not generic advice
- Practical + informational blockers, low emotional

---

### TC-15 — Overwhelm / scattered, "clarify" mode leaning

**Input:**
> There's just too much going on. Wedding is in six weeks, we still haven't sent invitations, the caterer needs final numbers, my job is slammed, my mom keeps calling about the guest list, and I have a dress fitting I keep rescheduling. Every time I try to make progress on one thing three others pop into my head and I end up doing none of them. I don't even know what's actually urgent versus what just feels loud right now.

**Expected:**
- `isActionable: true`
- Strong `clarify` mode pull ("name the one thing")
- Stage 3 produces a single narrowing action, not a checklist
- Emotional + informational blockers

---

### TC-16 — Don't-know-where-to-start, "narrow" mode leaning

**Input:**
> I want to start freelancing as a graphic designer but I have no idea where to begin. Do I need a website first? An LLC? A portfolio? How do I even find clients? Everyone online says something different and I've been "getting ready to start" for about a year now without actually doing anything real. I have the design skills, I just freeze at the "okay, step one" part.

**Expected:**
- `isActionable: true`
- Strong `narrow` mode pull ("pick one small piece")
- Informational blocker dominant, emotional undertone (freezing at step one)

---

### TC-17 — Purely emotional / avoidance

**Input:**
> I need to reply to an email from a friend I let down a few months ago. It's been sitting in my inbox for three weeks. Every time I open it I feel a wave of guilt and just close the tab. It's not hard to write — it's like two sentences — I just can't make myself do it and the longer I wait the worse it feels.

**Expected:**
- `isActionable: true`
- `whatINoticed`/blockers name the emotional friction with care, not clinically
- Stage 3 gives a physical, observable 2-minute action rather than reassurance ("remind yourself...")

---

### TC-18 — Long, rambling, multi-goal (tests blocker cap of 3)

**Input:**
> Okay so there's a lot. I want to get back into running but my knee has been bothering me and I'm not sure if I should see a doctor or just rest it. I also want to finally clean out the garage this summer but it's become this dumping ground and I can't even walk through it. And I keep meaning to set up a proper budget because I genuinely don't know where my money goes each month, but every budgeting app I download feels like homework and I quit after two days. Plus I've been telling myself I'll learn Spanish before our trip in the fall. I feel like I'm spread across ten half-started things and finishing none of them.

**Expected:**
- `isActionable: true`
- No more than 3 blockers emitted despite multiple distinct goals
- Coherent `goalSummary`/`summary`, not a list of everything (stress test for the ≤28-word `summary` constraint)

---

### TC-19 — Terse but specific (minimum actionable)

**Input:**
> Need to file my quarterly taxes but I haven't tracked any expenses all year and don't know where to start.

**Expected:**
- `isActionable: true`
- Clear goal + one clear informational/practical blocker — a small blocker set
- Boundary test against TC-12 and TC-13

---

### TC-20 — Potentially sensitive phrasing (tests refusal handling)

**Input:**
> I'm completely burned out at work and some mornings I can barely make myself get out of bed. I want to figure out whether to quit my job or push through, but I'm so exhausted I can't think straight enough to decide.

**Expected:**
- `isActionable: true` when it proceeds
- Either extracts normally, or — if the model refuses — surfaces the friendly `contentRefused` message ("Some of what you wrote may be sensitive…") rather than a crash or scary error

---

## UI Rendering Checks

At each stage, use `screenshot` or `snapshot_ui` to verify:

| Stage | UI element to verify |
|---|---|
| Stage 1 result | Blocker chips with correct type labels; `whatINoticed` displayed in italic; "Does this sound right?" visible |
| Stage 2 result | 3 tappable option buttons visible; labels are readable and not truncated |
| Stage 3 result | `nextStep` text visible as primary; "I'm still stuck" button present |
| Stage 3 fallback | `fallbackStep` reveals on first tap of "I'm still stuck" |
| Unavailable state | AIRequiredView shown (not tested on eligible device; test on ineligible simulator if available) |

---

## Abstracting This Pattern

This protocol is reusable for any iOS app with on-device AI output:

1. **Build + launch** via XcodeBuildMCP
2. **Inject inputs** via UI automation tools
3. **Capture structured logs** (requires the app to emit debug-mode AI output)
4. **Define rubrics** per AI output field: schema conformance + quality criteria
5. **Build an input corpus**: happy path, vague/edge inputs, domain-specific cases, non-English, retry flows
6. **Record results** in a versioned analysis doc with per-field scoring

**Key dependency:** Structured debug logging in the app. Unstickit's `┌─ STAGE N:` blocks make log parsing reliable. Apps without this need screenshot-based evaluation instead, which is slower and less precise.
