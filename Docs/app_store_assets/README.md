# App Store Release Assets — Screenshots

Captured 2026-07-06 for **Clear Next Step** (repo/bundle: Unstickit).
Companion to `Docs/app_store_release_assets_spec.md` (metadata copy, privacy label, review
notes all live there — this folder is the **screenshot** deliverable + capture notes).

## Captured screenshots (`screenshots/`)

All are **native 1320 × 2868** — the exact App Store Connect size for the **6.9" iPhone**
class (iPhone 17 Pro Max). Captured on the **iPhone 17 Pro Max, iOS 26.4 simulator**, light
appearance, standard status bar (9:41, full signal/wifi, charged).

| File | Screen | Notes |
|---|---|---|
| `01-brain-dump.png` | Brain Dump | Example dump typed in ("file my taxes…"). Empathetic entry point. Shows the current layout: ⓘ info button top-left, in-field clear (✕) top-right. |
| `02-reflection-choice.png` | Reflection + Choice | "Here's what I'm hearing" summary + three tappable options. |
| `03-next-step.png` | **Next Step (hero)** | The payoff: one small step. Use as screenshot-1 slot. |
| `04-recent-empty.png` | Recent tab | **Empty state** — see "Discrepancy" below. Weak store shot; optional. |
| `05-smaller-step.png` | Smaller step | "I'm still stuck" → an even smaller step. Reinforces "there's always a smaller one." |
| `06-about-privacy.png` | About / Privacy | Real in-app privacy screen (ⓘ → About sheet). "Private by design" + on-device statement. |

### Recommended store order + captions (per spec §5, calm voice)
1. `03-next-step.png` — **"One small next step."**
2. `01-brain-dump.png` — **"Start by writing what's stuck."**
3. `02-reflection-choice.png` — **"It reflects back what's really in the way."**
4. `05-smaller-step.png` — **"Still stuck? There's always a smaller one."**
5. `06-about-privacy.png` — **"Private by design — nothing leaves your phone."** (Now a real
   captured screen, not a composited caption frame — an in-app About/Privacy sheet was added this
   session, reached via the ⓘ button on the Brain Dump screen.)

## How these were captured (important — read before re-capturing)

The core flow needs on-device Apple Intelligence output. On the **iOS Simulator, guided
generation fails** because the `SensitiveContentAnalysisML` safety model isn't provisioned in the
simulator runtime. Every `LanguageModelSession.respond(generating:)` throws:

```
GenerationError Code=-1 → com.apple.SensitiveContentAnalysisML Code=15
  → NSCocoaErrorDomain Code=4865 "The data couldn't be read because it is missing."
```

`SystemLanguageModel.default.availability` reports `.available`, so the app does **not** show
`AIRequiredView` — it reaches the flow and then surfaces "Could not analyze your input." **This is
a simulator limitation, not an app bug**; a real qualifying iPhone has the safety model and the
flow works. (Spec §5 anticipates exactly this.)

To capture screens 2, 3, 5, a **DEBUG-only, env-gated stub** was temporarily added to
`AIService.swift` returning representative fixed output, then **reverted** after capture (source is
clean). It can never reach a Release binary (both `#if DEBUG` *and* an env var gate). To
re-capture (e.g. after the in-app copy unification in spec §1.1), re-apply this and launch with
`env {"UISTUB_CAPTURE": "1"}`:

```swift
// Top of extract(from:), clarify(extraction:), generateNextStep(...):
#if DEBUG
if AIService.isUICaptureStub { return AIService.stubExtraction(for: brainDump) }   // etc.
#endif

// DEBUG-only helpers on the actor:
#if DEBUG
static var isUICaptureStub: Bool { ProcessInfo.processInfo.environment["UISTUB_CAPTURE"] == "1" }

static func stubExtraction(for brainDump: String) -> ExtractionResult {
    ExtractionResult(
        isActionable: true, clarificationPrompt: nil,
        goalSummary: "You want to get your taxes filed and off your plate.",
        blockers: [
            Blocker(description: "The paperwork is scattered and it's unclear you have everything.", type: .practical),
            Blocker(description: "Opening the folder brings a wave of overwhelm, so you close it.", type: .emotional)
        ],
        frictionSummary: "Every time you start, the whole thing hits at once and you back away.",
        summary: "You want to file your taxes, but every time you open the folder it feels like too much and you close it again.")
}
static var stubClarification: ClarificationResult {
    ClarificationResult(options: [
        ClarificationOption(label: "I keep opening the folder, then closing it without making progress.", mode: .reproduce),
        ClarificationOption(label: "I don't know which part of this to start with.", mode: .narrow),
        ClarificationOption(label: "It all feels like too much and I can't focus.", mode: .clarify)])
}
static func stubNextStep(for mode: StuckMode) -> NextStepResult {
    switch mode {
    case .reproduce: return NextStepResult(nextStep: "Write one sentence about what happens each time you open the folder, then stop.", fallbackStep: "Write one sentence about what you tried, then stop.")
    case .narrow:    return NextStepResult(nextStep: "Pick the one tax document you're least sure about and open only that.", fallbackStep: "Name the one piece you're least sure about, then stop.")
    case .clarify:   return NextStepResult(nextStep: "Open the tax folder and read just the first page — nothing else.", fallbackStep: "Write 'I'm stuck because…' and stop.")
    }
}
#endif
```

Build → `install_app_sim` → `launch_app_sim` with the env var. Capture native res with
`xcrun simctl io <UDID> screenshot --type png <path>`.

> **Best practice:** the App Store screenshots that ship should ideally be captured on a **real
> qualifying iPhone** (15 Pro+) with genuine model output, since the pixels must match what ships.
> The stub is a fallback for the simulator's missing safety model. The stubbed text mirrors the
> shape of real output but is representative, not a live model result — re-shoot on device if you
> want strictly real output.

## ⚠️ Discrepancies found between spec/copy and the shipped binary — reconcile before submission

1. **No "Save" / no saved sessions in 1.0 — RESOLVED (copy fixed 2026-07-06).** The Next Step
   screen's actions are **Got it / I'm still stuck / Delete & start over** — there is **no Save
   button**. Tapping "Got it" does **not** persist anything; the **Recent tab shows "No recent
   sessions"** (session log is deferred out of 1.0, per `session_log_spec.md`). The only continuity
   that ships is the **next-day deferral card** on the Brain Dump screen ("pick up your step"). The
   store description + caption (spec §4/§5) previously said "Save a step for later" — now reworded
   to the truthful deferral framing ("your step can come back tomorrow — or you can let it go").
   Consequence: `04-recent-empty.png` is a weak shot; omit the Recent tab from the store set for
   1.0 (use `06-about-privacy.png` as shot 5 instead).
2. **Next Step buttons differ from spec §5** ("Start / I'm still stuck / Save" → actual
   "Got it / I'm still stuck / Delete & start over"). Cosmetic; the captured shots reflect the real
   binary, which is what matters.
3. **In-app name still "Unstick"/"Unstuck" in places** (spec §1.1) — unify to "Clear Next Step"
   before the final on-device re-capture so screenshots show one consistent name.
