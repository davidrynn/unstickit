# Unstuck AI Prompt Guidelines

## Purpose

This document defines the **AI behavior rules and prompt patterns** for the Unstuck application.

The goal of the AI in Unstuck is **not to solve the user's problem**.
The goal is to help the user **regain momentum** by identifying the smallest possible next step.

This distinction is critical to the product philosophy.

---

# Core Principle

The AI is a **re-engagement tool**, not a **problem solver**.

The goal is not insight. The goal is momentum. The best step is the **first real move on the
user's actual task** — small enough to start immediately, concrete enough that they know
exactly what to do, and specific to their situation.

A user who opens the permit form after tapping this app has succeeded. The step does not
need to solve anything — but it should **touch the real task**, not be an exercise *about*
the task. Meta-work ("categorize your tasks", "write about why you're stuck") reads as a
shrug; engagement ("open the application and gather the first document it asks for")
restores momentum.

*(Revised 2026-07-15: an earlier version of this principle said the step should be
"intentionally incomplete" and need not move the user toward the solution at all. In
real-device use that steered the model toward reflective meta-exercises that users found
unhelpful. The step should now be genuinely useful — a real first move — while still never
solving or diagnosing.)*

The AI should still **never attempt to solve the domain problem** — no diagnoses, no
technical fixes, no multi-step plans. Starting is the AI's job; solving is the user's.

---

# Activation vs Problem Solving

### Problem Solver Behavior (Avoid)

Examples:

- Check the terrain mesh stitching between chunks
- Debug the vertex update logic
- Inspect your noise sampling offsets
- Rebuild the terrain destruction pipeline

These attempt to **solve the technical issue**.

Unstuck should **not do this**.

---

### Activation Behavior (Preferred)

Examples:

- Write down when the terrain hole appears
- Try reproducing the bug once in isolation
- Open the project and run the game once, watching for the hole
- Capture a screenshot and describe the failure condition

These restore **momentum**: each one is a first real move on the actual task, without
presuming what the answer is.

---

# AI Interaction Stages

The AI interaction pipeline has **three stages**.

```
Brain Dump
↓
Extraction
↓
Clarification Options (tappable)
↓
Next Step
```

Each stage has specific responsibilities.

---

# Stage 1 — Situation Extraction

### Goal

Transform the user's raw description into a structured understanding.

Extract:

- goal
- practical blockers
- emotional friction

### Prompt Guidelines

The AI should:

- summarize the user's intent
- identify obstacles
- detect emotional friction
- remain concise

**Every blocker must trace back to something the user explicitly wrote.** Fewer blockers is
better — one real blocker beats three padded ones. The three blocker types
(practical/informational/emotional) are labels for what was found, **not slots to fill**: most
inputs will not include all three, and the model must never invent a blocker to cover a
missing type. (Observed failure, 2026-07-15: "app has problems" became a fabricated "there are
bugs" practical blocker, while the user's one concrete fact — the app's name is wrong — was
dropped. The fabrication then contaminated Stages 2 and 3.)

### Example Instruction

```
Analyze the user's description of what they are stuck on.

Extract:
- their goal
- practical blockers
- emotional friction

Return concise structured results.
```

---

# Stage 2 — Clarification Options

### Goal

Present 3 tappable options that let the user identify how they are stuck.

### Why tappable options instead of a question

Early versions of this stage asked the AI to generate an open-ended clarifying question,
which the user then answered via text input. This approach had two problems:

1. **Cognitive load**: Typing a response to an ambiguous question requires effort — exactly
   what stuck users have least of. Recognition (tapping an option) is far lower effort than
   recall (composing a typed answer).

2. **Model reliability**: On-device models struggle to generate *good* clarifying questions.
   In testing, the model generated technically complex, confusing questions that increased
   overwhelm rather than reducing it. Since the model must exercise nuanced judgment about
   what kind of question helps most, this is precisely where small models fail.

Tappable options solve both problems: the user taps rather than types, and the model only
needs to generate 3 short phrases — a much simpler task than generating a useful question.

### StuckMode Types

Each option maps to an internal `StuckMode` that constrains Stage 3 generation:

| Mode | What it means | Example label |
|------|--------------|---------------|
| `reproduce` | User has tried fixes repeatedly with no success | "I keep trying things and nothing works" |
| `narrow` | User doesn't know where to begin or what the real cause is | "I'm not sure where to even start" |
| `clarify` | User feels overwhelmed or scattered | "It feels too big and I can't focus" |

### Prompt Guidelines

- Generate exactly 3 options, one per `StuckMode`
- Each label must be a short first-person phrase specific to the user's situation
- Labels should be immediately recognizable — not abstract or technical
- Do not generate generic phrases ("I feel stuck") — make them situationally specific
- **Ground the prompt in the user's verbatim brain dump**, not just the Stage 1 extraction.
  The extraction is already abstracted (and can carry Stage 1 errors); without the user's own
  words the model has no concrete nouns to build labels from and falls back to parroting its
  own prompt. (Observed failure, 2026-07-15: all three options came back as near-verbatim
  copies of the prompt's example and mode descriptions.)
- Guard against prompt echoes in code, not just instructions: `AIService.isGenericOptionLabel`
  rejects labels that mostly restate the prompt's example or mode descriptions, and an echoed
  label triggers the same repair reroll as a missing mode.

### Good Option Labels

> "I keep trying fixes but the terrain holes keep appearing"

> "I'm not sure which system is even causing the problem"

> "There's too much going on and I don't know where to look first"

### Bad Option Labels

> "I have tried debugging"  ← too vague

> "What specific feedback does the AI provide for each terrain generation issue?"  ← not a label, this is a question; also increases cognitive load

---

# Stage 3 — Next Step Generation

### Goal

Generate the **smallest possible step that restores movement**, constrained by the user's
selected `StuckMode`.

### Why StuckMode constrains Stage 3

Without a mode, Stage 3 must infer what kind of step to generate from context alone.
Given rich technical context (goal, blockers, friction), on-device models default to
domain-specific solutions — which violates the activation-first philosophy.

By receiving the selected mode, Stage 3 knows exactly what kind of step to produce before
it starts. The model's hardest judgment (what kind of help is needed) moves to the user's
tap. The model only needs to fill in a situationally specific sentence in a known format.

### Mode-Specific Step Behavior

**`reproduce`** — User has tried multiple approaches with no success.

Point them back at the real thing with fresh eyes — open it, look at what actually
happened, or write down the last result.

> Run the game once and write down exactly when the terrain hole appears.

**`narrow`** — User isn't sure where to begin.

Pick the most concrete piece of their task and give them its very first move.

> Open the chunk-loading file and re-read just the section that stitches chunks together.

**`clarify`** — User feels overwhelmed or scattered.

Pick the single most pressing task they mentioned and give them its very first move.

> Open the permit application and gather the first document it asks for.

### Key Rules

The step must:

- be the **first real move on their actual task**, startable right now
- be one or two short sentences, at most ~30 words, starting with an action verb
- name a specific thing from *their* situation (their form, their file, their phone call)
- **never reference an artifact they didn't mention** (a "planning document", an email, a
  tool) — if the thing they need doesn't exist yet, the step is to *create its smallest
  first piece*, not to open it (observed failures, 2026-07-15: "open the ballet lesson
  planning document", "open the business promotion spreadsheet" — both invented). Prompt
  rules alone did not stop this, so it is **enforced in code**:
  `AIService.validationFailure` rejects steps naming artifact nouns (document, spreadsheet,
  email, form…) absent from the user's own words, unless framed as a fresh creation
  ("a new/blank X"). Rejection routes to the targeted repair, then the template.
- not attempt to solve the underlying problem or prescribe a multi-step plan

### Critical Constraint

The AI should **not attempt to solve the underlying problem**. Naming the user's specific
thing ("the permit form", "the chunk-loading file") is required; telling them what the
answer is ("the bug is in your noise sampling") is not allowed. No technical fixes, no
diagnoses, no multi-step plans.

---

# Fallback Step

Each response includes a **fallback step** shown when the user taps "I'm still stuck."

The fallback step should:

- be even smaller than the primary step
- take less than 5 minutes
- require almost no thinking to begin

Example:

Primary Step:

> Write down the exact conditions that cause the terrain hole to appear.

Fallback Step:

> Open a note and write: "When does the terrain hole appear?"

---

# Tone Guidelines

The AI should be:

- calm
- concise
- practical
- non-judgmental

Avoid:

- therapy-style language
- motivational speeches
- long explanations

---

# Example Full Flow

User Input:

> I'm stuck debugging terrain holes in my crafting game and I've already spent hours trying different AI fixes.

Extraction:

Goal — Fix terrain generation bug.
Blockers — Repeated debugging attempts with no progress.
Friction — Frustration and fatigue from failed attempts.

Clarification Options (tappable):

- "I keep trying fixes but the holes keep appearing" → `reproduce`
- "I'm not sure which system is causing it" → `narrow`
- "There's too much going on and I don't know where to look" → `clarify`

User taps: "I keep trying fixes but the holes keep appearing" (`reproduce`)

Next Step:

> Write down the exact steps that reliably cause the terrain hole to appear.

Fallback Step:

> Open a note and write: "When does the terrain hole appear?"

---

# Summary

The AI in Unstuck must prioritize:

```
Momentum > Insight
Clarity > Completeness
Action > Analysis
```

The tappable options architecture enforces this by moving the hardest judgment — what kind
of help is needed — to the user's tap, leaving the model responsible only for filling in
a situationally specific activation sentence.
