# ADR 0008 — Opt-in CloudKit analytics in 1.2; no third-party analytics SDKs

## Status
Proposed (target: 1.2)

## Context
The "Did this help?" flow (`Docs/did_this_help_spec.md`) produces the product's most important
signal — Yes vs. "Not quite" vs. retry-cap hits — and today none of it is visible beyond devices
we physically hold. TestFlight/App Store Connect offer no custom events; testers' choices from
the 1.0.x cycle are simply gone. The 1.0 posture is "Data Not Collected" with no SDKs
(`Docs/monetization_spec.md` constraints, memory: lean MVP).

Options considered:

- **On-device counters only** — add `outcome` + `regenerationCount` to the append-only
  `SessionLogStore` (defaulted `Codable` fields; the `completedAt` precedent proves legacy
  records survive). Zero privacy impact, but visible only via a debug/stats screen a tester
  screenshots back. Good enough for now; not a real feedback loop.
- **Opt-in CloudKit public-database counters** — a tiny anonymous record per resolved session
  ("completed, 1 retry"). Apple frameworks only: no SDK, no server, **no third party to trust**.
  Requires explicit opt-in UI and a privacy-label change to "Analytics — Data Not Linked to You".
- **Third-party analytics** — ad-funded SDKs (Firebase/GA) are disqualified outright: the data
  is partly their product and the SDKs over-collect. Paid privacy-focused vendors
  (TelemetryDeck, Aptabase) align incentives and have auditable open-source clients, but still
  add an SDK, a vendor relationship, and a trust delegation the CloudKit option makes unnecessary.
- **First-party endpoint** (URLSession → own worker) — same label cost as CloudKit but adds
  infrastructure to run, for no trust gain.

## Decision
1. **Now (1.0.x/1.1):** on-device only — stamp `outcome` and `regenerationCount` on the session
   log; no network, label unchanged.
2. **1.2 (probable):** ship **opt-in CloudKit public-DB counters** — anonymous aggregate events
   (outcome, retry count, mode; never dump text, never identifiers), off by default, one-line
   privacy-label update at that release.
3. **Never:** third-party analytics SDKs. Not because none are trustworthy, but because the
   CloudKit path gets the same numbers with no one else in the loop — the trust question is
   avoidable rather than answerable.

## Consequences
+ A real acceptance-rate feedback loop by 1.2 without breaking ADR 0001's privacy promise
  (raw text still never leaves the device — only counters do, with consent).
+ No vendor, no server, no SDK weight; consent UI is the only new product surface.
− Privacy label loses the flat "Data Not Collected" at 1.2 (becomes "Data Not Linked to You"),
  and opt-in participation will undercount.
− CloudKit public DB is write-easy but query-crude; reading aggregates means the CloudKit
  dashboard or a small script, not a analytics UI.
