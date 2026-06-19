# Unstuck — Come Back Tomorrow Spec

## Status
**Draft** — additive post-MVP option

**Depends on:** Recommended Steps. This feature uses `RecommendedStep` storage and should be built after the recommended steps foundation exists.

---

## 1. Purpose

The **Come back tomorrow** option gives users a gentle way to stop without treating stopping as failure.

It should support the product's activation goal:

> When the user cannot start today, help them leave with a clear, low-pressure return point.

This is not a streak feature, accountability feature, or guilt mechanic. It is a soft continuation affordance.

---

## 2. Product Intent

Some users will reach the next-step screen and still not be able to act. The current MVP handles this with:

- **Start**
- **I'm still stuck**
- fallback step
- retry from the original brain dump

The missing case is:

> "I understand the step, but I am not doing this today."

The app should let the user choose that honestly and preserve momentum for tomorrow.

---

## 3. Recommended Language

### Primary Button Label

**Come back tomorrow**

Why:
- clear
- plain
- non-judgmental
- avoids productivity pressure
- implies continuation, not abandonment

### Confirmation Copy

After tapping:

**We'll hold this for tomorrow.**

Supporting text:

**No need to solve it right now. When you come back, we'll start from this step.**

Primary action:

**Done**

Optional action:

**Set reminder**

### Tomorrow Return Copy

When the user returns the next day:

Title:

**Ready to pick this back up?**

Body:

**Here's the step you left for yourself.**

Primary action:

**Start**

Secondary action:

**Make it smaller**

Tertiary action:

**Let this go**

---

## 4. Copy Principles

Follow the shared copy rules in [copy_principles.md](copy_principles.md).

Use language that:

- treats delay as normal
- preserves agency
- avoids shame, urgency, or streak framing
- keeps the focus on one small action
- does not imply the app knows what is best for the user

Preferred phrases:

- "We'll hold this for tomorrow."
- "No need to solve it right now."
- "Start from this step."
- "Make it smaller."
- "Let this go."

---

## 5. Placement

Show **Come back tomorrow** on **S4 — Next Step**.

Recommended hierarchy:

1. Primary: **Start**
2. Secondary: **I'm still stuck**
3. Tertiary: **Come back tomorrow**
4. Tertiary / low-emphasis: **Save this step** if Recommended Steps is enabled

The option should be visible but quiet. It should not compete with **Start**.

---

## 6. Behavior

### Tap Come Back Tomorrow

When tapped, create exactly one local `RecommendedStep` record.

```swift
source = .deferredTomorrow
text = nextStep
fallbackText = fallbackStep
availableOn = next local calendar day at 5:00 AM, but never sooner than 6 hours after createdAt
expiresAt = createdAt + 7 days
isSaved = false
```

Rules:

- deferred steps are a view over `RecommendedStep` records where `source == .deferredTomorrow`
- `availableOn` is the next local calendar day at 5:00 AM, but never sooner than 6 hours after `createdAt`
- `expiresAt` is 7 days after `createdAt`
- deferred steps are stored locally on-device through the Recommended Steps store
- tapping **Come back tomorrow** clears the active draft
- if local notifications are enabled, offer an optional reminder
- if notifications are not enabled, do not block the flow

Out of scope: sync. If the user reinstalls the app or switches devices, deferred steps are not preserved.

---

## 7. Return Experience

On launch, if there is an unexpired `RecommendedStep` where `source == .deferredTomorrow && availableOn <= now`, show a lightweight return card above the normal brain-dump prompt.

Card content:

- title: **Ready to pick this back up?**
- step text
- actions: **Start**, **Make it smaller**, **Let this go**

Actions:

- **Start** leaves the recommended step active until it expires or is dismissed, and returns the user to the fresh S1 state
- **Make it smaller** shows `fallbackText` if available
- **Let this go** deletes the deferred step and keeps the user on S1

If `fallbackText` is missing, hide **Make it smaller**. Do not regenerate from the return card.

If multiple deferred steps exist, show only the most recent one in the return card. Older unexpired steps remain available in **Recent steps**.

---

## 8. Notifications

Notifications are optional and user-controlled.

Prompt copy:

Title:

**Want a gentle reminder tomorrow?**

Body:

**We can remind you to come back to this step.**

Actions:

- **Set reminder**
- **Not now**

Notification text:

**Unstuck**

**Ready to pick this back up?**

No guilt copy. No streak language. No repeated reminders unless the user explicitly creates one.

---

## 9. Edge Cases

- If the user returns before tomorrow, the deferred step does not interrupt the default S1 flow.
- If the deferred step expires after 7 days and is not saved, delete it automatically.
- If the user taps **Let this go**, delete immediately.
- If the user saves the step, it is no longer auto-deleted.
- If notifications are denied, the feature still works through the in-app return card.
- If the app has both a draft brain dump and a deferred step, it means the user deferred one step and later started a new draft. Prioritize the draft restore state and show the deferred step as a quiet card below it.

---

## 10. Acceptance Criteria

- [ ] S4 shows **Come back tomorrow** as a tertiary action
- [ ] Tapping it creates exactly one `RecommendedStep` with `source == .deferredTomorrow`
- [ ] Confirmation copy says **We'll hold this for tomorrow.**
- [ ] Active draft is cleared after deferring
- [ ] Deferred step appears on launch when `availableOn <= now`
- [ ] `availableOn` is never sooner than 6 hours after creation
- [ ] Return card offers **Start**, **Let this go**, and **Make it smaller** only when `fallbackText` exists
- [ ] Deferred step auto-deletes after 7 days unless saved
- [ ] Notification prompt is optional and does not block completion
- [ ] No copy uses guilt, streaks, pressure, or productivity shame
