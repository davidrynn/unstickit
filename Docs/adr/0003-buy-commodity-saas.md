# ADR 0003 — Buy commodity infrastructure; do not build it

## Status
Accepted

## Context
Shipping Unstickit (`Docs/ship_unstickit_spec.md`) requires analytics, crash reporting, and
subscription handling. There was a temptation to build a first-party backend for these.

The market already solves all of these as mature SaaS: App Store Connect / StoreKit (payments,
subscription state, basic analytics, crash), RevenueCat (entitlements), TelemetryDeck / Mixpanel /
PostHog (analytics), Sentry / Crashlytics (errors).

## Decision
**Buy the commodity layers; do not build them.** Unstickit introduces no first-party backend. A
backend is only justified by custom application logic over our own data that no SaaS provides —
which Unstickit's on-device design does not have.

Analytics must remain anonymous and carry no raw user text, preserving the ADR 0001 privacy
boundary.

## Consequences
+ Fastest path to a live, instrumented, monetizable app.
+ Keeps the privacy story clean (anonymous, event-level analytics only).
+ Avoids maintaining infrastructure that adds no product value.
− Dependence on third-party SDKs and their data practices (mitigated by choosing privacy-first
  vendors and scrubbing user text).
