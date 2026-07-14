# Release Readiness — Status & Handoff (1.0)

Status: In progress
Last updated: 2026-07-05

> **Branding decided (2026-07-05):** App display name = **Clear Next Step** (home screen + store).
> Company / entity = **Fieldlight Interactive** → use in the ASC **Copyright** field
> (`© 2026 Fieldlight Interactive`) and on the support/privacy page. NOTE: the App Store
> *seller/developer name* is inherited from the Apple Developer account type (individual shows
> "David Rynn"; to show "Fieldlight Interactive" the account must be an Organization) — user's call,
> not a build setting.

> **Purpose:** a durable snapshot of where the *free 1.0 App Store release* actually stands, so
> the work can continue in a fresh session without re-auditing. This is a status log on top of the
> canonical plans — it does **not** re-decide anything.
>
> **Canonical plans (defer to these):**
> - `ship_unstickit_spec.md` — the ship track (lean MVP, no SDKs, "Data Not Collected").
> - `app_store_release_assets_spec.md` — paste-ready store metadata, screenshots, privacy label,
>   review notes, support/privacy page, §8 build & submission checklist.
>
> **Posture reminder:** 1.0 is **asset + config work, no new feature code.** No analytics/crash
> SDK, no RevenueCat (ADR 0006). Privacy label = **"Data Not Collected."**

## Project audit — actual state as of 2026-07-05

### Already done ✅
- **Version** `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1`.
- **Export compliance:** `ITSAppUsesNonExemptEncryption = NO` set (no export prompt).
- **No entitlements** declared — clean privacy story, nothing to strip.
- **In-app copy already unified** — no user-facing "Unstick/Unstuck" strings remain (only code
  identifiers/comments). Tab is "Start", not a duplicate of the app name. (Resolves the two §1.1
  code follow-ups in `app_store_release_assets_spec.md`.)
- **App icon:** `Assets.xcassets/AppIcon.appiconset/Unstiku_Icon.png` is 1024×1024, **no alpha**.
  Dark/tinted appearance slots are declared but empty (optional; not a blocker).
- **Bundle ID:** `com.davidrynn.unstiku` (keep as-is at release, per spec).

### Gaps to close ⚠️
1. ~~**Home-screen display name missing.**~~ **DONE (2026-07-05).** `INFOPLIST_KEY_CFBundleDisplayName
   = "Clear Next Step"` set on both app-target configs (Debug + Release). Verified in the built
   bundle's `Info.plist` (`CFBundleDisplayName = Clear Next Step`). It truncates on the home screen
   to ~"Clear Next…" as expected — accepted per user decision (whole app is "Clear Next Step").
2. ~~**No `PrivacyInfo.xcprivacy`.**~~ **DONE (2026-07-05).** Authored `Unstickit/PrivacyInfo.xcprivacy`:
   `NSPrivacyTracking = false`, empty tracking domains, empty collected data types (= "Data Not
   Collected"), UserDefaults required-reason `CA92.1`. Auto-included via the target's Xcode-16
   synchronized folder; verified present in the built `.app`.
3. ~~**Deployment target is iOS 26.2.**~~ **DONE (2026-07-05).** Lowered `IPHONEOS_DEPLOYMENT_TARGET`
   to **26.0** across all targets. Verified `MinimumOSVersion = 26.0` in the built bundle.
4. ~~**Landscape enabled.**~~ **DONE (2026-07-05).** iPhone locked to portrait
   (`UISupportedInterfaceOrientations~iphone = [Portrait]` in the built plist). iPad left with its
   default four orientations (decision was iPhone-scoped; iPad is the universal fallback) — can be
   locked too if desired.

All four verified via a successful Debug simulator build (scheme `Unstickit`, iPhone 17 Pro).

## Next actions

### Claude can do (no accounts needed)
- [x] Author `PrivacyInfo.xcprivacy` (Data Not Collected + UserDefaults reason). **Done 2026-07-05.**
- [x] Set `INFOPLIST_KEY_CFBundleDisplayName`; lower min iOS to 26.0; portrait lock. **Done 2026-07-05.**
- [ ] Capture the **5 screenshots** per `app_store_release_assets_spec.md` §5. **BLOCKED (2026-07-05)
      — needs a user decision.** Ran the 1.0 build on the iPhone 17 Pro Max (6.9") sim; the app lands
      on the `AIRequiredView` "Turn On Apple Intelligence" gate — this Mac's simulator reports
      `appleIntelligenceNotEnabled` (eligible hardware, model not downloaded). The 4 AI-dependent
      shots (Brain Dump populated → Reflection/Choice → Next Step → Saved) can't be captured until
      one of:
      (a) user enables Apple Intelligence + downloads the model in macOS System Settings (it flows to
      the sim) → then drive the real flow (spec's preferred, most-honest path); or
      (b) temporarily stub `AIService` with fixed sample output *for capture only*, then revert (spec
      §5 permits, if documented as representative). Not done autonomously — it edits product code and
      hand-authors store-facing AI text that should be reviewed first.
      **Bonus finding:** the gate screen reads "Clear Next Step uses on-device Apple Intelligence…",
      confirming in-app copy is already unified to the store name (no "Unstuck" strings) — corroborates
      the §1.1 audit.
- [x] Draft the **support / privacy one-pager** HTML (user hosts on GitHub Pages / Notion / Framer).
      Privacy copy matches "Data Not Collected" exactly (spec §7). **Done 2026-07-05** →
      `Docs/support_page/index.html`.

### Requires the user (accounts / external)
- [ ] App Store Connect: create/confirm app record; enter §2–§4 metadata (already drafted,
      paste-ready in the spec); set privacy label to **"Data Not Collected"** (spec §3); add §6
      App Review notes (pre-empts the Apple-Intelligence-device rejection).
- [ ] Host the support/privacy page; paste the Support + Privacy Policy URLs into ASC.
- [ ] Signing (Distribution cert + App Store profile; automatic signing fine).
- [ ] Archive (Release) → validate → upload → TestFlight; smoke-test one eligible + one ineligible
      device (confirm `AIRequiredView`); then Submit for Review.

## Open decisions
- ~~**Home-screen app name**~~ → RESOLVED: "Clear Next Step" (2026-07-05). Done.
- ~~**Min iOS 26.0 vs 26.2**~~ → RESOLVED: 26.0 (2026-07-05). Done.
- ~~**Portrait-only vs keep landscape**~~ → RESOLVED: iPhone portrait-only (2026-07-05). Done.
- **Screenshot capture path** (NEW, open) — enable real Apple Intelligence on the Mac vs. stub
  `AIService` for capture vs. capture later on a real device. See the blocked screenshot item above.
- **iPad orientation** (minor, open) — iPad still allows 4 orientations; lock to portrait too? The
  portrait decision was iPhone-scoped. Left as-is for now.
