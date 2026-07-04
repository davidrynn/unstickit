# Sample Brain Dump Inputs

Paste-ready inputs for testing the Brain Dump → Clear Next Step flow. Each one is
labeled with what it's meant to exercise in the three AI stages:

- **Stage 1 — Extraction:** `goalSummary`, `blockers` (practical / informational / emotional),
  `frictionSummary`, `whatINoticed`, `summary`, `isActionable`.
- **Stage 2 — Clarification:** three options, one per mode (`reproduce`, `narrow`, `clarify`).
- **Stage 3 — Next Step:** one tiny 2-minute action, plus the smaller "I'm still stuck" fallback.

---

## 1. Well-rounded happy path (all three blocker types)

> I've been trying to launch a small side project — a paid newsletter about home coffee roasting — for like four months now and I keep not shipping it. I have maybe 15 draft posts sitting in Notion. Every time I sit down to actually publish, I convince myself the writing isn't good enough yet, or I get pulled into researching which platform to use (Substack vs. Ghost vs. just my own site) and lose the whole evening comparing features. I still don't have a clear sense of who I'm even writing this for — hobbyists? people trying to go pro? I also haven't figured out the payment/tax side and honestly I'm a little scared that if I charge money and nobody subscribes it'll prove I'm not actually good at this. I have the time, I have the material, I just can't seem to get it out the door.

**Exercises:** clear goal; all three blocker types (practical = payment/tax, informational = audience + platform, emotional = fear of failure); a non-obvious pattern for `whatINoticed` (platform research as avoidance); all three Stage-2 modes plausible. `isActionable: true`.

---

## 2. Vague / thin input (should NOT be actionable)

> I don't know. I'm just stuck on everything lately and can't get anything done.

**Exercises:** the `isActionable: false` path — no specific goal, no describable blocker. Should return a warm `clarificationPrompt` asking for more context rather than proceeding to blockers.

---

## 3. Single-word / fragment (hard NOT-actionable)

> Taxes

**Exercises:** the extreme low-signal case. Single word, no context. Must return `isActionable: false` and a friendly clarifying question, not a hallucinated goal + blockers.

---

## 4. Code bug — "reproduce" mode leaning

> I'm building a SwiftUI app and there's a bug where the next-step screen sometimes shows the old result for a split second before updating. I've tried moving the state into an @Observable, adding .id() to force a redraw, and wrapping the update in a Task — nothing has fixed it and I'm not even sure which change did what anymore. I've been at it for two days and every fix seems to create a new weird flicker somewhere else. I just want this one screen to update cleanly so I can move on.

**Exercises:** a concrete technical goal with a clear "I tried many things and none worked" signal → strong `reproduce` mode pull in Stage 2; domain-specific Stage-3 step (should reference their code/error, not generic advice). Practical + informational blockers, low emotional. `isActionable: true`.

---

## 5. Overwhelm / scattered — "clarify" mode leaning

> There's just too much going on. Wedding is in six weeks, we still haven't sent invitations, the caterer needs final numbers, my job is slammed, my mom keeps calling about the guest list, and I have a dress fitting I keep rescheduling. Every time I try to make progress on one thing three others pop into my head and I end up doing none of them. I don't even know what's actually urgent versus what just feels loud right now.

**Exercises:** many competing threads, no single blocker → strong `clarify` mode pull ("name the one thing"). Tests that Stage 3 produces a single narrowing action, not a checklist. Emotional + informational blockers. `isActionable: true`.

---

## 6. Don't-know-where-to-start — "narrow" mode leaning

> I want to start freelancing as a graphic designer but I have no idea where to begin. Do I need a website first? An LLC? A portfolio? How do I even find clients? Everyone online says something different and I've been "getting ready to start" for about a year now without actually doing anything real. I have the design skills, I just freeze at the "okay, step one" part.

**Exercises:** clear goal, undefined path → strong `narrow` mode pull ("pick one small piece"). Informational blocker dominant, emotional undertone (freezing at step one). Good test of the intention-vs-action `whatINoticed`. `isActionable: true`.

---

## 7. Purely emotional / avoidance

> I need to reply to an email from a friend I let down a few months ago. It's been sitting in my inbox for three weeks. Every time I open it I feel a wave of guilt and just close the tab. It's not hard to write — it's like two sentences — I just can't make myself do it and the longer I wait the worse it feels.

**Exercises:** a tiny practical task with a large emotional blocker → tests that the AI names the emotional friction with care (not clinical), and that Stage 3 gives a physical, observable 2-minute action rather than reassurance ("remind yourself..."). `isActionable: true`.

---

## 8. Long, rambling, multi-goal (tests blocker cap of 3)

> Okay so there's a lot. I want to get back into running but my knee has been bothering me and I'm not sure if I should see a doctor or just rest it. I also want to finally clean out the garage this summer but it's become this dumping ground and I can't even walk through it. And I keep meaning to set up a proper budget because I genuinely don't know where my money goes each month, but every budgeting app I download feels like homework and I quit after two days. Plus I've been telling myself I'll learn Spanish before our trip in the fall. I feel like I'm spread across ten half-started things and finishing none of them.

**Exercises:** multiple distinct goals → the model must NOT emit more than 3 blockers, and should synthesize a coherent `goalSummary`/`summary` rather than listing everything. Good stress test for the "1 to 3 blockers" and ≤28-word `summary` constraints.

---

## 9. Terse but specific (minimum actionable)

> Need to file my quarterly taxes but I haven't tracked any expenses all year and don't know where to start.

**Exercises:** the low end of "just enough detail to be actionable." Clear goal + one clear informational/practical blocker. Should be `isActionable: true` with a small blocker set — a good boundary test against #2 and #3.

---

## 10. Potentially sensitive phrasing (tests refusal handling)

> I'm completely burned out at work and some mornings I can barely make myself get out of bed. I want to figure out whether to quit my job or push through, but I'm so exhausted I can't think straight enough to decide.

**Exercises:** emotionally heavy but legitimate stuck-situation. Verifies the flow handles heavy language gracefully — either extracts normally or, if the model refuses, surfaces the friendly `contentRefused` message ("Some of what you wrote may be sensitive…") rather than a crash or a scary error. `isActionable: true` when it proceeds.

---

## Quick reference

| # | Purpose | Expected `isActionable` | Mode lean |
|---|---------|:-----------------------:|-----------|
| 1 | Happy path, all blocker types | true | any |
| 2 | Vague overwhelm | **false** | — |
| 3 | Single word | **false** | — |
| 4 | Code bug, tried many fixes | true | reproduce |
| 5 | Scattered / overwhelmed | true | clarify |
| 6 | Don't know where to start | true | narrow |
| 7 | Emotional avoidance | true | clarify/narrow |
| 8 | Many goals at once | true | clarify |
| 9 | Terse but specific | true | narrow |
| 10 | Sensitive phrasing | true (or graceful refusal) | clarify |

---

## Appendix: verified on-device output (2026-07-03)

Three of these were run through the real pipeline (`extract → clarify → generateNextStep`)
on an iOS 26.5 simulator with Apple Intelligence available. Output is non-deterministic —
this is a sample, not an expected-value contract.

**#1 Coffee newsletter → `isActionable: true`**
- goalSummary: "You want to launch a paid newsletter about home coffee roasting and get it published."
- summary: "You want to launch a paid newsletter about home coffee roasting, but perfectionism, platform confusion, and fear of failure are holding you back from publishing."
- whatINoticed: "You're caught in a loop of perfectionism and overthinking, which prevents you from making progress."
- blockers: `[emotional]` writing never good enough · `[informational]` platform-comparison rabbit hole · `[emotional]` unclear audience + fear of no subscribers
- options covered all three modes; nextStep (reproduce): "Write down the three platforms you've tried and what didn't work for you."

**#2 Vague overwhelm → `isActionable: false`** (correctly gated)
- clarificationPrompt: "Could you tell me a bit more about what you're trying to accomplish?"

**#4 SwiftUI flicker bug → `isActionable: true`**
- goalSummary: "You want to fix a bug in your SwiftUI app where the next-step screen sometimes shows an old result for a split second before updating."
- nextStep (reproduce): "List all the functions you've tried so far and what happened with each one."

**Prompt-tuning observation:** for #4, `whatINoticed` restated the blocker ("overwhelmed by
the complexity…") instead of surfacing a *non-obvious* pattern, and two blockers were both
typed `[emotional]`. #1's `whatINoticed` was stronger. Worth a look if the "I noticed" insight
underwhelms on technical inputs.

### Environment note (to actually run the flow)

The on-device flow only runs when the app is **built with Xcode 26.5** (matching the iOS 26.5
runtime). Building with Xcode-beta (27.0 SDK) makes the app crash on launch with a dyld
`Symbol not found: FoundationModels.Generable.promptRepresentation` error, because that symbol
doesn't exist in the 26.5 runtime. Simulator UI automation likewise needs Xcode 26.5
(`SimulatorKit.framework` is absent from Xcode-beta).
