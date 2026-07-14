# ADR 0007 — Skip a blanket MVVM layer for this app

## Status
Accepted (experiment, provisional)

## Context
Default policy on SwiftUI projects has been MVVM with a dedicated service/data layer. MVVM's
original case was built for UIKit, where a heavyweight, imperative view controller needed
something else to hold business logic. SwiftUI's `View` is already a lightweight, declarative
value type driven by state (`@State`, `@Observable`, bindings) — much of what MVVM existed to
provide is arguably built into the framework now, and there's active, unresolved debate in the
SwiftUI community about whether a formal ViewModel-per-view layer still earns its cost or just
adds an extra translation step.

Unstickit is small (eight screens) and much of it was written with heavy AI assistance (Claude
Code). That raised a second, more specific question: without an explicit MVVM guardrail forcing
a shape, does AI-assisted development drift — logic leaking into views, inconsistent patterns
across screens — or does it stay organized on its own?

## Decision
No blanket MVVM layer is mandated. Concretely:

- Views own genuinely view-local UI state directly via `@State`/`@Observable`, rather than
  proxying every screen through a ViewModel.
- Navigation is centralized in shared `@Observable` state rather than routed through per-view
  ViewModels or closure callbacks.
- A thin service layer (`AI/AIService.swift`) and a small set of model stores
  (`Models/RecommendedStepStore.swift`, `SessionLogStore.swift`, `DeferredReminder.swift`,
  `ProInterestStore.swift`) still separate business/persistence logic from views — that
  separation was kept, since it wasn't the part under test.
- Two of the eight screens (`ReflectionChoiceView`, `NextStepView`) grew a small dedicated model
  object (`ReflectionChoiceModel`, `NextStepModel`) once their non-navigation state (reveal/restart
  state machines, defer-confirmation flow) got complex enough to be worth extracting. These were
  added ad hoc, per screen, not as an upfront rule applied everywhere.

## Consequences
+ Less boilerplate and indirection for the app's actual size; most screens read straight from
  `@State`/`@Observable` without an extra translation layer.
+ AI-assisted sessions stayed reasonably organized without the guardrail — no significant
  logic-leaking-into-views drift observed so far.
+ Where a screen did need extracted state, adding it stayed small, legible, and easy to justify.
− Verdict is provisional. This is a small app with a small screen count; it's still an open
  question whether "extract state only when it hurts" holds up as the app grows — more screens,
  more shared state, more AI-assisted sessions compounding decisions independently. Revisit if
  state logic starts leaking into views inconsistently or duplicating across screens.
− This is a scoped experiment for this app, not a new default. The normal policy (MVVM + a
  service/data layer) still applies elsewhere unless a similar test is deliberately run again.
