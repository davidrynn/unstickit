# Unstuck — Product Plan (Iteration 3)

## Current Stage

This project is currently in **late planning / pre-spec**.

That means:
- the **product concept is mostly locked**
- the **core workflow is defined**
- some **implementation-facing decisions** have started
- but we have **not yet written the formal MVP spec**

A good way to frame it is:

**PLAN → locked concept → MVP SPEC**

We are at the **"locked concept"** end of planning, right before spec writing.

---

## Product Summary

**Working name:** Unstuck

**Core promise:**

> When you're stuck, the app helps you find the next step.

The app is a **structured problem-solving tool** focused on **activation**.

It is not primarily:
- a task manager
- a journal
- a therapy app
- a general chatbot

Its main purpose is to help users move from:

**confusion → clarity → one concrete action**

---

## Core User Problem

People get stuck during projects, not just at the beginning.

This can happen when:
- the next step is unclear
- there are too many possible directions
- progress feels slow and painful
- uncertainty makes action feel risky
- small tasks turn into rabbit holes
- emotional friction makes starting hard

Traditional productivity tools fail here because they assume the user already knows what the task is.

This app is for the moment before that.

---

## Product Philosophy

The app should feel like a **calm, structured thinking assistant**.

It should:
1. let the user describe what they are stuck on
2. reflect back the situation in simple structured language
3. ask a very small number of clarifying questions
4. produce **one concrete next step**

The app should be **simple, bounded, and action-oriented**.

---

## Locked Product Decisions

### 1. Primary goal
The app's primary purpose is **activation**.

### 2. Interaction style
The app should feel like a **structured problem-solving tool**, not a freeform chat app.

### 3. Emotional handling
The app may acknowledge emotions briefly as **action friction**, but should avoid deep emotional analysis.

### 4. First screen prompt
The first prompt should be:

**What are you stuck on?**

### 5. Output format
The app should produce **one concrete next step**, not a three-step plan.

### 6. Platform / AI direction
For now, the app should target **on-device Apple Intelligence** / Apple on-device models as the primary AI direction.

---

## Core Product Loop

1. User opens the app
2. User sees: **What are you stuck on?**
3. User writes a brain dump
4. AI reflects back:
   - likely goal
   - likely blockers
   - what may be making it hard
5. AI asks **1–2 clarifying questions**
6. AI generates **one concrete step**
7. App optionally offers a fallback even-smaller step

This is the full loop.

---

## Why the Product Might Matter

The product is not just “ChatGPT in another app.”

Its value comes from:
- **structure**
- **low-friction entry**
- **bounded interaction**
- **activation-first output**

The key product insight so far:
- simply writing things down already helps
- AI reflection adds useful structure
- one small step helps users actually start

This suggests the product's value is:

**structured externalization + light AI guidance**

not “deep AI coaching.”

---

## MVP Scope

### Included
- Brain-dump input
- AI reflection
- 1–2 clarifying questions
- One concrete next step
- Optional fallback smaller step
- Saved sessions

### Excluded
- project management features
- long-term planning
- team collaboration
- deep coaching / therapy behavior
- complex multi-turn chat
- heavy integrations

---

## Draft Screen Flow

### Screen 1 — Brain Dump
Title: **Unstuck**

Prompt:
**What are you stuck on?**

Controls:
- large text input
- CTA button such as **Help me think this through**

### Screen 2 — Reflection
Show short structured reflection:
- Goal
- Possible blockers
- What might be making this hard

Then ask **clarifying question 1**.

### Screen 3 — Clarification
Show one question at a time.
At most **2 questions total**.

### Screen 4 — Next Step
Show:
- **Your next step**
- optional **If that still feels hard** fallback

Potential actions:
- Start
- I'm still stuck

---

## AI Behavior Direction

The AI should be constrained into stages.

### Stage 1 — Extraction
From the brain dump, infer:
- goal
- practical blockers
- emotional friction

### Stage 2 — Clarification
Ask **one focused question** that reduces ambiguity.

### Stage 3 — Next Step Generation
Generate:
- one concrete next step
- one fallback smaller step
- short reasoning for internal/app use

The AI should avoid:
- long essays
- vague productivity advice
- therapy language
- large multi-step plans

---

## Technical Direction

### Current preference
Use **on-device Apple Intelligence / Apple on-device model access** as the initial AI path.

### Implication
This means the app design should stay:
- highly structured
- short-context
- prompt-constrained
- lightweight in reasoning demands

That fits the current product direction well.

---

## Key Risks

### Risk 1 — It feels too similar to ChatGPT
Mitigation:
- strong structure
- very short loop
- always end with one action

### Risk 2 — It becomes another thinking rabbit hole
Mitigation:
- max 2 clarification questions
- one-step output only

### Risk 3 — On-device AI may be weaker than large hosted models
Mitigation:
- narrow the task to extraction, reflection, clarification, and next-step generation
- keep prompt contracts tight

---

## Validation Insights So Far

From role-play testing:
- the workflow helped with a workplace influence problem
- the workflow helped with a game-development motivation/debugging problem
- writing itself reduced overwhelm
- the structured response produced actionable next steps
- blocker identification felt useful

This suggests the concept is promising.

---

## What Comes Next

The next document should be the **MVP spec**.

That spec should define:
- exact screens
- state machine
- AI contracts / prompt contracts
- structured model outputs
- data model
- acceptance criteria
- what counts as done for MVP

---

## Resolved Decisions

1. **Blocker types** — Internal by default. Exposed on demand via disclosure tap on each blocker.
2. **Fallback smaller step** — Shown on demand only, when user taps "I'm still stuck."
3. **Edit-and-regenerate** — Re-run from scratch only. User can tap a past session and tap "Try again" to re-run the full loop with the same brain dump. No partial regeneration for MVP.
4. **Minimum Apple Intelligence** — iOS 18.1+, Apple Intelligence enabled, A17 Pro or later (iPhone 15 Pro / iPhone 16+). Show a clear "Apple Intelligence required" screen if device doesn't qualify. No cloud API fallback for MVP.
5. **Sessions in MVP** — Yes, included. Save completed sessions (brain dump + next step), list view, tap to view. No editing.

---

## AI Output Schema

### Stage 1 — Extraction

```swift
@Generable
struct ExtractionResult {
    /// If false, skip reflection screen and show clarificationPrompt inline on Screen 1
    let isActionable: Bool

    /// Shown inline on Screen 1 if isActionable == false
    let clarificationPrompt: String?

    /// Only valid if isActionable == true
    let goalSummary: String
    let blockers: [Blocker]
    let frictionSummary: String
}

@Generable
struct Blocker {
    let description: String   // shown to user
    let type: BlockerType     // internal, revealed on demand
}

@Generable
enum BlockerType: String, Generable {
    case practical       // missing info, resources, skills
    case informational   // unclear path or criteria
    case emotional       // fear, avoidance, overwhelm
}
```

### Stage 2 — Clarification

Input: `ExtractionResult` + optional previous Q&A pair (if second question)

```swift
@Generable
struct ClarificationResult {
    let question: String   // shown to user
    let intent: String     // internal — what ambiguity this resolves
}
```

App runs Stage 2 up to twice. Second invocation includes the first Q&A in the prompt context.

### Stage 3 — Next Step Generation

Input: `ExtractionResult` + all `ClarificationResult` Q&A pairs

```swift
@Generable
struct NextStepResult {
    let nextStep: String      // primary output, shown on Screen 4
    let fallbackStep: String  // shown only when user taps "I'm still stuck"
    // reasoning discarded after generation, not stored
}
```

### Stage Flow

```
BrainDump (String)
    │
    ▼ Stage 1
ExtractionResult
    │
    ├─ isActionable == false → show clarificationPrompt on Screen 1 → user adds more → re-run Stage 1
    │
    └─ isActionable == true
            │
            ▼ Stage 2 (×1–2)
        ClarificationResult(s)
            │
            ▼ Stage 3
        NextStepResult
```

---

## Working Process

Recommended workflow:

1. iterate this plan until it feels tight
2. write MVP spec
3. derive implementation tasks from the spec
4. build a thin prototype
5. test with real scenarios
