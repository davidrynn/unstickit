# Ticket: Add a GitHub README using the App Store screenshots

Status: Open
Filed: 2026-07-13

## Why

The repo has no root-level `README.md` — a visitor landing on the GitHub repo sees only source
files, not what the app is or does. We already have polished, on-brand screenshots captured for
the App Store listing (`Docs/app_store_assets/`); reusing them is the cheapest way to give the
repo a real front page without a separate asset-creation pass.

## Assets already available

`Docs/app_store_assets/screenshots/` (6.9", 1320×2868 — use these, they're the higher-res set;
`screenshots_6.7/` is a duplicate set at the 6.7" size, not needed for a README):

| File | Screen |
|---|---|
| `03-next-step.png` | Next Step (hero shot — the payoff) |
| `01-brain-dump.png` | Brain Dump (entry point) |
| `02-reflection-choice.png` | Reflection + Choice |
| `05-smaller-step.png` | "I'm still stuck" → smaller step |
| `06-about-privacy.png` | About / Privacy sheet |
| `04-recent-empty.png` | Recent tab, empty state — **weak, see caveat below** |

`Docs/app_store_assets/README.md` already has a recommended order + calm-voice captions for the
first 5 (§"Recommended store order + captions") — reuse that copy rather than redrafting.

## Caveat — verify before using `04-recent-empty.png` or reusing captions verbatim

`Docs/app_store_assets/README.md` §"Discrepancies" (written 2026-07-06) notes the Recent tab was
empty because sessions weren't persisted yet. `retain_completed_sessions_spec.md` (status:
Implemented, 2026-07-08) shipped *after* that capture — completed sessions are now retained
on-device, though they still don't surface in the Recent tab by design (see
`Docs/known_issues.md` #3). Bottom line: the empty-state screenshot is likely still accurate for
what the Recent tab visibly shows today, but confirm on a current build rather than assuming the
2026-07-06 notes are still current — and skip it either way, since the App Store README already
flags it as a weak/optional shot.

## Scope

Create `README.md` at the repo root with:
1. **Title + one-line pitch** — what "Clear Next Step" does (turns a stuck brain-dump into one
   small next action), pulling from the store description in
   `app_store_release_assets_spec.md` rather than redrafting from scratch.
2. **Screenshot gallery** — the 5 non-empty-state shots above, in the recommended order, using
   the existing captions as alt text / figure captions. Markdown image table or side-by-side
   `<img>` tags, sized to render reasonably in GitHub's README viewer (~250-300px wide each).
3. **How it works** — a short paragraph on the 3-stage on-device flow (brain dump → reflection +
   choice → next step), and that it runs entirely on-device via Apple's FoundationModels /
   Apple Intelligence (ties into the privacy story — "Data Not Collected").
4. **Requirements** — iOS 26.0+, a device eligible for Apple Intelligence (per
   `AIRequiredView` gating already in the app) for the AI flow to work at all.
5. **Status / links** — App Store link once live (placeholder or omit until submitted per
   `release_readiness_status.md`); Support/Privacy page link (`Docs/support_page/`).
6. Skip build/dev-setup instructions unless the repo is meant to accept outside contributors —
   confirm with the user whether this is a public-facing showcase README or a contributor-facing
   one, since that changes whether a "Building" section belongs.

## Out of scope

- Capturing new screenshots — reuse what exists; only re-capture if the caveat above turns up a
  real discrepancy.
- Rewriting App Store copy — pull from the existing spec, don't originate new marketing copy here.

## Next action

Confirm with the user: is this README meant to be a public marketing-style front page (portfolio
piece, App Store companion) or a contributor/dev-setup README? That determines whether sections
5-6 above are needed.
