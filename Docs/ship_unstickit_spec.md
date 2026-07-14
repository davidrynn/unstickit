# Ship Unstickit — Commercialization & Release Spec

Status: Draft
Owner: David Rynn
Last updated: 2026-06-29

> **Goal of this track:** get the free, on-device Unstickit app *live and instrumented* —
> a real, monetizable product with users. Everything here is commodity SaaS integration — the
> *correct* engineering choice (buy, don't build) — with no first-party backend introduced.

## Principle: buy the commodity layers

The app needs analytics, crash reporting, and subscription plumbing. All three are solved
problems with mature SaaS. **Do not build them.** Building commodity infra you could buy adds
maintenance cost with no product benefit; integrate it cleanly and know *why you bought it*.
No first-party backend is introduced in this track.

## The privacy constraint overrides everything

Unstickit's thesis is that the core flow is **100% on-device and private** — raw brain-dump text
never leaves the phone. Every SaaS added here must honor that:

- **Anonymous, event-level analytics only.** No raw brain-dump text, no reflected summaries, no
  next-step text. Events carry structured metadata only (e.g. `blockerTypes`, `chosenMode`,
  outcome flags, prompt version) — the same shape already defined as `SessionSignal` in
  `pattern_detection_spec.md`.
- Prefer a **privacy-first analytics vendor** (e.g. TelemetryDeck) over a behavioral-graph
  vendor, so the App Store privacy nutrition label stays clean and the positioning stays honest.
- Crash reporting must scrub any user text from breadcrumbs/logs.

## In scope

### 1. Analytics (the load-bearing piece)
Analytics is not vanity here — it produces the **evidence that gates Pro**. Per
`monetization_spec.md` and `pattern_detection_spec.md`, Pro is post-MVP and gated on two
observations: (a) the core loop retains users, and (b) real subject recurrence exists across
sessions. We cannot make that go/no-go call without instrumentation.

- Integrate a privacy-first analytics SDK.
- Define and emit a small, deliberate event set: session started/resolved, stage reached, chosen
  mode, blocker types, outcome (save / defer / still-stuck / bail), prompt version.
- These events are the on-device demand/retention probe alongside the existing `ProInterestStore`
  counter.

### 2. Crash / error reporting
- Integrate Sentry or Crashlytics (commodity). Scrub user text. Wire release health.

### 3. RevenueCat integration — DEFERRED to the Pro track (ADR 0006)
**Superseded.** This section originally called for RevenueCat "plumbing now, paywall later." ADR
0006 reverses the timing: RevenueCat and the `isPro` state owner are **out of the free-app ship
track**. With no paywall, no products, and nothing to gate, `isPro` would flip zero features, and
Pro itself is post-MVP and evidence-gated (ADR 0004) — it may never ship. Build RevenueCat + the
app-level `isPro` owner + a sandbox-verified purchase as the **first step of the Pro track**, only
once the evidence gate greenlights Pro. Buying (not building) entitlements remains correct (ADR
0003); only the timing changed.

### 4. Release readiness
- App Store Connect app record, screenshots, description, privacy nutrition labels (must reflect
  the anonymous-analytics reality).
- TestFlight build → public TestFlight or App Store submission.
- Confirm `AIService.isAvailable()` gating + `AIRequiredView` for ineligible devices reads well
  to a cold reviewer.
- Basic remote kill/config is **optional** here and, if wanted, is the *one* place a tiny
  first-party `GET /v1/config` could live — but treat it as out of scope unless a real need
  appears; do not invent a backend for it.

### 5. In-app feedback (mail composer, not a backend)
Early-user feedback is wanted, but it is a **bought/commodity concern, not a reason to build a
backend** — a backend is only justified by custom application logic over your own data, and
"collect feedback" does not qualify.

**Decision (2026-07-03): use the system mail composer (`MFMailComposeViewController`) for 1.0.**

- **Why the composer over an anonymous hosted form (Tally/Formspree/etc.):** any network form
  submission means data flows off-device, which would **flip the "Data Not Collected" label** the
  whole ship track is protecting. The composer sends **from the user's own mail account on an
  explicit Send tap** — the app never transmits anything itself, so the label stays clean. The
  cost is real and accepted: feedback is **not anonymous** (sender's email is visible) and it's a
  little higher-friction (composer opens, extra tap).
- **Implementation notes for build time:**
  - UIKit, so it needs a small `UIViewControllerRepresentable` wrapper.
  - Guard on `MFMailComposeViewController.canSendMail()` — no configured Mail account means the
    composer can't open; need a `mailto:` fallback or a disabled/hidden state.
  - Prefill a hidden debug block (app version, iOS version, device model). The user sees it before
    sending, so it stays inside "Data Not Collected."
- **Placement: undecided.** Candidates are a quiet toolbar/overflow → sheet, or an eventual
  Settings/About surface. Do **not** put it on the brain-dump/Start screen (secondary affordances
  stay quiet there). Resolve when the Settings/About question is decided; not a 1.0 blocker for
  this decision, only for wiring.

## Out of scope (defer to canon)

- **Live paywall and Pro features** — post-MVP, gated on evidence (`monetization_spec.md`).
- **The session log** — **deferred out of MVP** (see build order). It does no user-facing good and
  its recurrence signal isn't actionable until users have multi-session history months out, so it
  is a trigger-gated follow-up, not a launch blocker (`session_log_spec.md`).
- **Pattern detection** — post-MVP (`pattern_detection_spec.md`).
- **Any first-party backend, sync, accounts, web surface** — those belong to Track 2 and to the
  product's eventual Pro tier, not to shipping the free app.
- Android, cloud AI for the free flow.

## Build order

This is the authoritative ship sequence (free app). **Lean-MVP posture (decided 2026-07-02): ship
1.0 with no third-party SDKs at all** — no analytics SDK, no crash SDK, no session log. 1.0 is
core-flow + free Apple-provided telemetry only. RevenueCat stays deferred (ADR 0006).

The 1.0 gating question — *does the core loop retain?* — is answered **for free, zero code** by:
- **App Store Connect analytics** → downloads + day-1/7/28 **retention curves**.
- **Xcode Organizer** → **crash reports** + MetricKit metrics from App Store/TestFlight builds,
  automatically (no SDK, no MetricKit code).

The in-app **funnel** and **symbolicated crash dashboards** are refinements on top of that — needed
once there are installs worth dissecting, not to make the retain / don't-retain call. So both are
deferred. This keeps 1.0 to **asset/config work, no new feature code**, and lets the privacy label
stay the strongest possible: **"Data Not Collected."**

1. **App Store Connect setup** — app icon, screenshots (capturable in the Simulator — Apple
   Intelligence runs there), metadata (drafted in `app_store_release_assets_spec.md`), **privacy
   label = "Data Not Collected,"** review notes (drafted). Support + a trivial privacy-policy
   one-pager for the two required URLs.
2. **TestFlight → submission** — smoke-test one eligible + one ineligible device (confirm
   `AIRequiredView`), then submit.

*1.0 tradeoff (accepted):* coarse retention only, no per-stage funnel — you'll know *whether*
people return, not *which stage* they abandon, until the analytics follow-up ships.

**Deferred follow-up A (post-launch, trigger-gated): privacy-first analytics SDK + crash SDK.**
When retention (from free App Store Connect data) shows a pulse and you want to know *why* people
drop off, add a protocol-wrapped analytics SDK (TelemetryDeck / PostHog / Aptabase — ADR 0003) with
a **typed event enum** so no case can carry user text (funnel: session started, stage reached,
chosen mode, blocker types, outcome, `aiError` + prompt version — the last is also the ADR-0002
reliability signal). Add Sentry for symbolicated crashes only if Xcode Organizer proves thin.
Shipping this **flips the privacy label** to Usage Data → Product Interaction (+ Diagnostics),
not-linked-to-identity, no-tracking/no-ATT, and the privacy policy must gain a matching line. Also
requires a `promptVersion` constant in `AIService` (none today).

**Deferred follow-up B (post-launch, trigger-gated): the session log.** Make
`StuckMode`/`BlockerType` `Codable`, add `SessionLogEntry` + `SessionLogStore`, write one entry per
resolved session — the **subject-recurrence** evidence Apple's analytics cannot provide. Spec:
`session_log_spec.md`. *Why not in 1.0:* it surfaces nothing to users, and recurrence isn't
readable until users accumulate multi-session history (months out), so shipping it in the first
build buys only weeks of history you can't yet act on — while dragging an on-device-retention
privacy disclosure into the launch. **Trigger:** ship it once retention (free App Store Connect
data) shows a pulse — i.e. the moment Pro starts looking worth validating; natural to bundle with
follow-up A. Tie it to that signal, not to a vague "when we build Pro," so it isn't forgotten and
restarted from zero history.

Deferred (Pro track, not here): **RevenueCat + `isPro` owner** — see §3 and ADR 0006.

## Done when

- The free app is publicly installable (public TestFlight or App Store).
- Privacy label is **"Data Not Collected"** and the privacy policy matches (no SDKs in 1.0).
- **Retention** data is accruing via **free App Store Connect analytics**; crashes are visible in
  **Xcode Organizer**. No third-party analytics/crash SDK in 1.0.
- Analytics SDK, crash SDK, and the session log are all tracked as trigger-gated follow-ups (ship
  on a retention signal), **not** in 1.0.
- RevenueCat is **not** in this track — it ships with Pro (ADR 0006).

## References

- `session_log_spec.md` — deferred post-launch follow-up (trigger-gated on a retention signal);
  the subject-recurrence evidence source.
- ADR 0006 — defer RevenueCat until Pro is real.
- `monetization_spec.md` — canonical free/Pro line; no paywall in MVP.
- `pattern_detection_spec.md` — the evidence gate analytics feeds; `isPro` owner; `SessionSignal`
  event shape.
- `unstuck_mvp_spec.md` — MVP scope and the dumb session log.
