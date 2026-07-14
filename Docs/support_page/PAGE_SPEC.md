# Support & Privacy Page — Build Spec

For the person/agent building the **Clear Next Step** support page on the existing
`*.github.io` site. This is drop-in content + the decisions behind it. Match your site's
own styling; the copy below is final and must be used verbatim where quoted.

A **reference implementation** (standalone, styled, light/dark) already exists at
`Docs/support_page/index.html` — reuse its copy; restyle to fit the site.

---

## 0. Why this page exists

App Review **requires** a reachable **Support URL** and a **Privacy Policy URL** for every app.
One page covers both (and doubles as the optional Marketing URL). It is also linked from **inside
the app** (the About sheet), so the privacy wording here must match the app and the App Store
privacy label **exactly**.

## 1. Data-handling decision (this is what makes the privacy policy truthful)

**Option 1 ONLY — all data stays on device.**

- ❌ No accounts, no servers of ours.
- ❌ No iCloud/CloudKit sync.
- ❌ No analytics or crash reporting (no third-party or Apple analytics SDK in 1.0).
- ❌ No in-app purchases or subscriptions in 1.0.
- ✅ 100% on-device processing via Apple Intelligence. Anything the app keeps for the user is
  stored only on their device.

The App Store privacy label for this app is **"Data Not Collected"** — the page must not say
anything that contradicts that.

## 2. URLs — two pages (RESOLVED 2026-07-06)

Both paths are **stable and ship in the binary + store listing** — don't repurpose them later.

| Page | URL | Used as |
|---|---|---|
| Support (main page, §3) | `https://davidrynn.com/clear-next-step/` | App Store Connect **Support URL**; `AboutView` **Support** link; optional Marketing URL |
| Privacy Policy (standalone, §3b) | `https://davidrynn.com/clear-next-step/privacy` | App Store Connect **Privacy Policy URL**; `AboutView` **Privacy Policy** link |

A dedicated `/privacy` path lands the App Review reviewer directly on the policy (no scrolling
past support content), and lets the policy grow/version independently when the analytics
follow-up ships in a later release.

## 3. Page content (final copy — use verbatim)

### Header
- **Title / H1:** `Clear Next Step`
- **Tagline:** `Find one small thing to do next — private and on-device.`

### Support section
- Heading: `Support`
- Body: `Questions, feedback, or something not working? Get in touch and I'll help.`
- Contact (mailto link): `davidrynn@gmail.com`

### FAQ section
Heading: `Frequently asked`

**Q: Why does it need an iPhone 15 Pro or later?**
> Clear Next Step runs entirely on your device using Apple Intelligence. That on-device model
> needs an iPhone 15 Pro or later with Apple Intelligence turned on. If your device isn't
> eligible, the app tells you rather than sending anything to a server.

**Q: Where is my data?**
> On your phone, and only your phone. Everything you write is processed on-device and never leaves
> it. There's no account and no cloud copy. Anything the app keeps for you — like a step you come
> back to — stays on your device.

**Q: Do you see what I write?**
> No. What you type never reaches me or anyone else. There's no server that could receive it.

### Privacy Policy section (on the main page)
Heading: `Privacy Policy`

Either keep the full paragraph here (see §3b) **or** replace it with a one-line link to the
standalone page: `Read the privacy policy →` (`/clear-next-step/privacy`). If the paragraph
appears in both places, the wording must be identical.

### Footer
- `© 2026 Fieldlight Interactive`

## 3b. Standalone privacy page (`/clear-next-step/privacy`) — final copy

A small, quiet page. Same styling family as the main page.

- `<title>Clear Next Step — Privacy Policy</title>`
- **H1:** `Privacy Policy`
- **Subline:** `Clear Next Step`
- **Body (verbatim):**

> Clear Next Step does not collect any data. Everything you write is processed on your device and
> never leaves it. There is no account, no server, and no analytics or tracking of any kind.

- `Last updated: July 2026.`
- Contact line: `Questions? davidrynn@gmail.com` (mailto link)
- A back link to the main page (`← Clear Next Step support`)

This paragraph must stay **word-for-word identical** to the in-app About sheet's privacy statement
and consistent with the App Store **"Data Not Collected"** label. If any surface changes, change
all of them together.

## 4. Page metadata

- `<title>Clear Next Step — Support &amp; Privacy</title>`
- Responsive (mobile-first), light **and** dark mode, no external requests (self-contained /
  no CDN fonts or scripts) — reviewers and users may open it on a phone.

## 5. Guardrails (don't violate)

- **Voice:** calm and plain. Avoid productivity-pressure words: *tasks, to-do, complete, overdue,
  priority, streak, productivity.*
- **Don't mention** Pro, premium, subscriptions, "pattern detection," or analytics — **none of
  these ship in 1.0.** Describing them here is a false claim.
- The **Privacy Policy paragraph must stay identical** to (a) the in-app About sheet's privacy
  statement and (b) the App Store "Data Not Collected" label. If any of the three changes, change
  all three.
- **Don't over-claim a "save" feature.** The FAQ wording above ("anything the app keeps for you")
  is deliberately neutral so it's true whether or not an explicit save ships. Keep it that way.

## 6. When it's live

Reply with the URL. It then gets wired into `AboutView` (`supportURL` / `privacyURL`) and entered
in App Store Connect. Done.
