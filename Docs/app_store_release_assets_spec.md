# App Store Release Assets — Spec

Status: Draft
Owner: David Rynn
Last updated: 2026-07-02

> **Goal of this spec:** produce every asset App Store Connect asks for to submit Clear Next Step
> (the repo/project is still "Unstickit"; the App Store name is **Clear Next Step**) —
> metadata copy, screenshots, privacy labels, and App Review notes — with paste-ready drafts, so
> submission is a data-entry step, not a writing step.
>
> This is the concrete deliverable for **`ship_unstickit_spec.md` §4 (Release readiness)** and
> build-order step 4. It does **not** re-decide scope, monetization, or privacy posture — it
> defers to canon for all of that and only turns those decisions into store-facing copy and
> images.

## Guardrails inherited from canon (do not violate in any asset)

- **Privacy is the thesis.** Raw brain-dump text never leaves the device; the core flow is 100%
  on-device Apple Intelligence (ADR 0001). Every asset — description, screenshots, privacy label
  — must reinforce this, never undercut it. If a sentence could make a reviewer think text is
  uploaded, cut it.
- **No paywall, no Pro in the shipped build** (`monetization_spec.md`, ADR 0006). Do **not**
  mention Pro, subscriptions, "premium," pattern detection, or "learns how you get stuck" anywhere
  in store copy. The store must describe only what ships: the free, on-device flow. Selling a
  feature that isn't in the binary is an App Review rejection risk and an honesty violation.
- **Voice = `copy_principles.md`.** Calm activation, not productivity pressure. **Never** use
  *tasks, to-do, complete, overdue, priority, streak, productivity* in marketing copy, or
  motivational-poster lines ("Don't give up," "Keep your streak alive"). Keywords field is exempt
  (it's for search indexing, see §4).

---

## 1. Open decisions — resolve before submission

These change the assets and are the user's call. Recommended default listed first; the spec is
written assuming the default so nothing is blocked.

1. **App name / branding — RESOLVED: "Clear Next Step"** (2026-07-02). This is the App Store
   display name (15 chars, ≤30). "Unstickit" remains the **repo / bundle / project** identifier —
   these are allowed to differ; only the store display name and in-app copy need to agree.
   Two follow-ups this creates (code tasks, not store tasks):
   - **Unify in-app copy** to the store name: on-screen strings still say **"Unstuck" / "Unstick"**
     (`AIRequiredView.swift:18`) — update them to "Clear Next Step" before submitting so the
     reviewer sees one consistent name.
   - **Tab-name collision:** the first tab is already labeled **"Clear Next Step"**
     (`RootTabView.swift:17`). With the whole app now named that, an identically named tab is
     redundant — consider relabeling the tab (e.g. to the flow's action) so the name isn't doubled.
     Cosmetic; not a submission blocker.
2. **Marketing + support + privacy-policy URLs.** App Review **requires** a reachable Support URL
   and (because analytics/tracking data types are declared) a **Privacy Policy URL**. A one-page
   static site covers all three. Recommended: a single GitHub Pages / Notion / Framer page. See §7.
3. **Screenshot capture path.** Simulators generally cannot run Apple Intelligence, so real
   on-device screens must come from a qualifying iPhone (15 Pro+). See §5 for the fallback.
4. **First version number & "What's New" for 1.0** — trivial, drafted in §4.

---

## 2. App identity (App Store Connect › App Information / Pricing)

| Field | Value | Notes |
|---|---|---|
| App name | **Clear Next Step** | 15 chars (≤30). See §1.1. |
| Subtitle | **Get unstuck, one small step** | 28 chars (≤30). Shown under the name on the product page + search. |
| Bundle ID | (existing) | From the Xcode project; do not change at release. |
| Primary category | **Productivity** | Best-fit store taxonomy for discovery. (This is the *store category*, not marketing copy — the copy-principles ban on the word "productivity" does not apply to a fixed enum field.) |
| Secondary category | **Health & Fitness** *(optional)* | Only if it reads honestly; the app is not a wellness/therapy app (`copy_principles.md`). Leave blank if unsure. |
| Price | **Free** (Tier 0) | No IAP configured (ADR 0006). |
| Age rating | **4+** | No objectionable content. Answer all questionnaire items "None." |
| Availability | All territories, **English** primary | Localization is out of scope for 1.0. |

**Device availability wrinkle:** the app requires Apple Intelligence + A17 Pro-class hardware
(`unstuck_mvp_spec.md §2`). This is enforced at runtime via `AIService.isAvailable()` →
`AIRequiredView`, **not** via an App Store device family restriction. Do **not** try to hide the
app from older devices in App Store Connect; instead the description (§4) states the requirement
plainly and the in-app gate handles ineligible installs gracefully. Confirm the deployment target
and `UIRequiredDeviceCapabilities` in the project don't over- or under-restrict before archiving.

---

## 3. Privacy nutrition label (App Privacy section)

This is the highest-stakes asset because the app's whole positioning is privacy. Fill it to match
the **anonymous-analytics reality** (`ship_unstickit_spec.md`), not aspirationally.

**Core flow data (brain-dump text, reflections, next steps):**
- **Not collected.** It never leaves the device (ADR 0001). Declare **nothing** for this data —
  because nothing is transmitted, it is not "collected" under Apple's definition. Saved steps and
  the session log are on-device only.

**Analytics SDK (if the privacy-first analytics SDK from `ship_unstickit_spec.md` step 3 ships in
1.0):**
- Data type: **Usage Data → Product Interaction**, and possibly **Diagnostics → Crash Data** /
  **Performance Data** (from crash reporting).
- Linked to identity: **No** (anonymous, event-level only).
- Used for tracking: **No** (no cross-app/advertising tracking; no ATT prompt needed).
- Purpose: **Analytics** (and **App Functionality** for crash/performance).
- **Guarantee to preserve:** events carry structured metadata only (`blockerTypes`, `chosenMode`,
  outcome flags, prompt version — the `SessionSignal` shape), **never** raw text. If the analytics
  SDK is **not** in the 1.0 binary, declare **"Data Not Collected"** for the whole app and move the
  above into the version that first ships analytics.

**Do not** declare data types the binary doesn't actually send. An over-declared label is as much
a trust problem as an under-declared one, and it contradicts the marketing claim.

---

## 4. Store metadata copy (paste-ready)

All fields respect App Store Connect character limits (noted). Voice per `copy_principles.md`.

### Subtitle (≤30 chars)
```
Get unstuck, one small step
```

### Promotional text (≤170 chars — editable anytime without review)
```
When you're stuck, Clear Next Step helps you find one small thing to do next. Private and on-device — what you write never leaves your phone.
```

### Description (≤4000 chars)
```
Stuck? Overwhelmed? Staring at something you can't seem to start?

Clear Next Step helps you find one small thing to do next — the kind that's easier to do than to keep avoiding. Not a plan. Not a to-do list. Just the next move.

HOW IT WORKS
Write down whatever you're stuck on, in your own words. Clear Next Step reflects back what it hears — your goal, and what might be getting in the way — then offers a few ways you might be stuck. You pick the one that feels true. It gives you a single, small step to get moving again.

Still stuck? Ask for a smaller one. There's always a smaller step.

PRIVATE BY DESIGN
Everything happens on your iPhone, using Apple Intelligence. What you write never leaves your device — no account, no cloud, no one reading your thoughts. That privacy isn't a setting you turn on; it's how the app is built.

CALM, NOT PUSHY
Clear Next Step doesn't track streaks, nag you, or make you feel behind. Getting stuck is normal. Letting a step go is allowed. The only goal is to help you get back in motion — gently.

Save a step for later, or come back to it tomorrow. No pressure either way.

REQUIRES APPLE INTELLIGENCE
Clear Next Step runs entirely on-device, so it needs an iPhone 15 Pro or later with Apple Intelligence turned on. If your device isn't eligible, the app will tell you.
```
*(Reads clean to a cold reviewer, states the device requirement so an ineligible-device tester
isn't surprised, and never mentions Pro/paywall.)*

### Keywords (≤100 chars, comma-separated, no spaces — search only, copy-principles exempt)
```
stuck,unstuck,focus,adhd,procrastination,overwhelm,motivation,mental health,private,ai,calm
```
*(Do not repeat words already in the app name/subtitle — "next step," "clear," and "unstuck" are
covered by the name + subtitle, so they're omitted here. Tune after launch using App Store Connect
search analytics.)*

### What's New (1.0) (≤4000 chars)
```
First release. Clear Next Step helps you find one small thing to do next when you're stuck — private, on-device, and calm. Thanks for trying it.
```

### Support & marketing URLs
- **Support URL** (required): see §7.
- **Marketing URL** (optional): same one-pager is fine.
- **Privacy Policy URL** (required once analytics is declared): see §7.

---

## 5. Screenshots

Apple requires screenshots for **6.9" iPhone** (e.g. iPhone 16 Pro Max) and **6.5"/6.7"** classes;
one uploaded set can be reused/scaled per current App Store Connect rules — confirm the current
required sizes at archive time. Target **iPhone only** (no iPad build in scope).

### Shot list (5 screens, in narrative order)
1. **Brain Dump** (`BrainDumpView`) — the "What are you stuck on?" prompt with an example dump
   typed in. The empathetic entry point.
2. **Reflection + Choice** (`ReflectionChoiceView`) — goal + blockers reflected back, three
   tappable "which feels most true" options. Shows the AI understands.
3. **Next Step** (`NextStepView`) — one clear step with **Start** / **I'm still stuck** / **Save**.
   The payoff shot; make this the hero (screenshot 1 slot).
4. **Saved tab** (`RecentStepsView`) — a couple of saved steps. Shows continuity without implying
   a task manager.
5. **Privacy / on-device** — either the app in use with a caption emphasizing on-device, or a
   clean caption-only frame. Reinforces the thesis.

### Captions (calm voice; short overlay text, optional)
- Hero: **"One small next step."**
- Reflection: **"It reflects back what's really in the way."**
- Choice: **"You pick what feels true."**
- Privacy: **"Private by design — nothing leaves your phone."**
- Saved: **"Save a step. Come back tomorrow. No pressure."**

### Capture path (resolves Open Decision §1.3)
- **Preferred:** capture on a real qualifying iPhone (15 Pro+) with Apple Intelligence on, using
  realistic-but-non-sensitive example brain-dump text (e.g. "I need to file my taxes but every
  time I open the folder I get overwhelmed and close it"). Never ship a screenshot with real
  personal content.
- **If a device isn't available:** the on-device model won't run in the simulator, so screens that
  depend on AI output must be **staged** — run the flow on device once, or temporarily stub
  `AIService` with fixed sample output *for capture only* (never ship the stub). Document that the
  screenshots are representative real output, not mockups.
- Optionally frame with a device bezel + caption, but keep it honest — the pixels must match what
  ships.

---

## 6. App Review notes (Review Information)

This is where a submission like this most often gets rejected, because **the reviewer's test
device may not support Apple Intelligence** and they'll hit `AIRequiredView` and think the app is
broken. Pre-empt it in the notes field:

```
Clear Next Step runs entirely on-device using Apple Intelligence (Foundation Models). It requires an iPhone 15 Pro or later with Apple Intelligence enabled — please review on a qualifying device.

If tested on an ineligible device, the app intentionally shows an "Apple Intelligence Required" screen and blocks the flow; this is expected behavior, not a crash.

There is no account, login, or server. Nothing the user types is uploaded — all processing is local. There is no in-app purchase or paywall in this version.

To try the core flow: on the first tab, type what you're stuck on (a few sentences), tap "Find my next step," pick one of the three options, and you'll get a single next step.
```

- **Demo account:** not applicable (no login) — say so.
- **Contact info:** real email + phone for the reviewer.
- **Sign-in required:** No.

---

## 7. Support / privacy surface (one static page covers all required URLs)

Minimum viable, no backend (consistent with "buy the commodity layers" / no first-party server in
Track 1):

- **Support page:** one-line what-it-is + a contact email (or a simple contact form) + a short FAQ
  ("Why does it need an iPhone 15 Pro?", "Where is my data?" → on-device answer). A GitHub Pages /
  Notion / Framer page is enough.
- **Privacy policy:** short and honest — brain-dump content is processed **on-device only** and
  never transmitted; the app collects **anonymous, non-identifying usage analytics and crash
  diagnostics** (only if that SDK is in the shipped build — otherwise state "no data is
  collected"). No third-party ad tracking, no data sale. This must **match §3's label exactly.**
- Same URL may serve as Marketing URL.

---

## 8. Build & submission checklist (App Store Connect + Xcode)

1. **App icon** — 1024×1024 App Store icon present and all in-app sizes filled; no alpha, no
   rounded corners baked in.
2. **Version / build** — set version to **1.0**, increment build number; archive a Release config.
3. **Signing** — Distribution certificate + App Store provisioning profile; automatic signing is fine.
4. **Capabilities audit** — confirm no unused entitlements are declared (e.g. no push, no iCloud)
   so the privacy story stays clean.
5. **Privacy manifest (`PrivacyInfo.xcprivacy`)** — present and consistent with §3; declare any
   required-reason APIs the analytics/crash SDKs use.
6. **Archive → validate → upload** via Xcode Organizer (or `xcodebuild`), land the build in App
   Store Connect / TestFlight.
7. **TestFlight smoke test** on a real qualifying device (the whole loop end-to-end) **and** on an
   ineligible device (confirm `AIRequiredView`).
8. Fill all §2–§7 metadata, upload §5 screenshots, attach §6 review notes.
9. **Submit for review.**

Sequencing note: per `ship_unstickit_spec.md` build order, the **session log (step 1)** must ship
in this same 1.0 binary — it's the last MVP feature and the evidence source. Don't submit a build
missing it.

---

## 9. PR / launch materials (lightweight — optional, not a submission blocker)

The user asked for "pr." Keep it small; it's launch comms, not part of App Store Review.

- **One-liner / tagline:** *"Clear Next Step — find one small thing to do next, private and on-device."*
- **Short pitch (≤300 chars)** for Product Hunt / social / a "Show HN"-style post — reuse the
  promotional text (§4), add "built entirely on Apple Intelligence, no cloud."
- **The angle that carries the portfolio signal** (`staff_..._portfolio_spec.md §6`): this is an
  AI app that is **not** a chatbot wrapper — a small on-device model made production-reliable via
  structured outputs, validation, and deterministic fallbacks. Lead the launch post and any case
  study with the reliability-engineering story + the privacy stance, not a feature list.
- **Assets to reuse:** the §5 hero screenshot + the §4 description condense into a launch post with
  zero new writing.
- Case study / README live in the portfolio track, not here — reference, don't duplicate.

---

## 10. Done when

- Every §2–§7 field has final (not placeholder) copy and the required URLs are live and reachable.
- Screenshots for all required device sizes are uploaded and match the shipped binary.
- The privacy label (§3) and the privacy policy (§7) say the same thing, and both match what the
  binary actually does.
- App Review notes (§6) pre-empt the Apple-Intelligence-device gotcha.
- The 1.0 build includes the session log (per `ship_unstickit_spec.md` build order) and passes the
  §8 checklist.
- App name is resolved (§1.1) and in-app copy is unified to match.

## References

- `ship_unstickit_spec.md` §4 — parent (Release readiness); this spec is its concrete deliverable.
- `monetization_spec.md` / ADR 0006 — no paywall/Pro in the shipped build (store copy must not
  mention Pro).
- `copy_principles.md` — voice for all marketing copy; the banned-word list.
- ADR 0001 / ADR 0002 — on-device + reliability story behind the privacy claim and the launch angle.
- `unstuck_mvp_spec.md` §2 — device requirement (drives §2, §5, §6).
- `session_log_spec.md` — must be in the 1.0 binary (build-order dependency, §8).
- `staff_mobile_product_engineer_portfolio_spec.md` §6 — the launch/case-study angle (§9).
</content>
</invoke>
