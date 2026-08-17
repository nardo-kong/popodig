# 19 — Implementation Roadmap

**Status: PROVISIONAL sequencing / LOCKED gate discipline**

## Rule
Do not build later content to compensate for an unproven core loop. Every milestone has an acceptance gate.

# Phase 0 — Repository & Engineering Foundation
## Deliverables
- Godot 4.7 project boots cleanly;
- folder architecture;
- test runner;
- CI/local validation script where practical;
- debug/release feature flag;
- logging categories;
- base config loader;
- screenshot capture helper.

## Gate
Clean import/parse + smoke test + deterministic test harness.

# Phase 1 — Grid World Foundation
## Deliverables
- `WorldGrid` and `CellData`;
- chunk representation;
- terrain presentation;
- camera pan/zoom;
- seeded blank/simple terrain generation;
- debug cell inspector.

## Gate
Large test map renders without one-Node-per-cell architecture; cell edits update correctly.

# Phase 2 — Digging & Dynamic Topology
## Deliverables
- dig designation/cancel;
- legal frontier evaluation;
- terrain hardness/progress;
- topology update;
- basic pathfinding;
- one mouse executes DigJob.

## Gate
Player can freely sketch a legal dig path and mouse completes it reliably.

# Phase 3 — Colony Jobs & Minimal Needs
## Deliverables
- 3 mice;
- hunger/rest/safety;
- job queue/reservation;
- hauling;
- basic Food/Material;
- debug job/path overlay.

## Gate
Autonomy runs for extended simulation without deadlock or required direct control.

# Phase 4 — Zones
## Deliverables
- Sleeping/Storage/Food zones;
- paint/edit/reassign;
- suitability;
- automatic setup/dressing placeholders;
- storage hauling.

## Gate
A small burrow supports normal mouse life with only space/priority commands.

# Phase 5 — Structured Worldgen
## Deliverables
- skeleton;
- strata;
- landmarks;
- feature placement framework;
- terrain fill;
- validation/repair;
- seed debug UI;
- batch seed tests.

## Gate
Target seed batch reaches agreed validation success rate with no required-path softlocks.

# Phase 6 — Signal & Root Feature
## Deliverables
- SignalSystem;
- root density field;
- root presentation bands;
- Root Cluster lifecycle;
- forage/food integration;
- recognition state.

## Gate
Naive tester can learn that root cues predict a root/food opportunity.

# Phase 7 — Water System
## Deliverables
- discrete water cells;
- finite reservoir;
- dampness signals;
- breach reaction;
- seal;
- emergency haul;
- room wetness;
- stable-pool sleep optimization.

## Gate
Multiple player-created topologies produce predictably different water outcomes; conservation tests pass.

# Phase 8 — Stability System
## Deliverables
- weak soil;
- local span evaluation;
- warning bands;
- reinforce/support;
- bounded collapse;
- path/zone update;
- related VFX/audio placeholders.

## Gate
Player can predict and intentionally avoid/solve at least two instability situations.

# Phase 9 — Vertical Slice UX & Tutorial
## Deliverables
- complete first 30–45 min flow;
- contextual tutorial;
- HUD/inspector;
- event notifications;
- camera event helpers;
- touch controls if in slice scope.

## Gate
External playtest against `18_VERTICAL_SLICE_ACCEPTANCE.md`.

# Phase 10 — Save/Load & Hardening
May be implemented earlier incrementally; final gate here.

## Deliverables
- schema version;
- atomic save;
- fixtures;
- mid-water/mid-hazard load;
- regression suite;
- performance profiling.

## Gate
No known blocker/critical state loss.

# Phase 11 — Art Integration Pass
## Deliverables
- locked tile scale/palette;
- production terrain transitions;
- mouse animation set;
- root/water/unstable complete art states;
- automatic zone dressing;
- audio/VFX pass;
- screenshot QA.

## Gate
No obvious AI-asset seams/borders/perspective conflicts; signals remain readable.

# Phase 12 — Vertical Slice Decision Gate
Possible outcomes:
### GO
Core dig decisions are fun. Proceed to Chapters 2/3.

### ITERATE
Loop promising but signal/hazard/topology needs redesign. Do not expand content.

### NO-GO / PIVOT
Dig decision itself is not interesting after multiple iterations. Reassess concept before adding systems.

# Phase 13 — Chapter 1 Production
- content density tuning;
- final onboarding;
- more authored root/topsoil variations;
- population/progression pacing;
- chapter milestone.

# Phase 14 — Chapter 2: Adapt
- foundation/stone structures;
- richer water configurations;
- overlap water + instability;
- pipe/heat/sound feature if validated;
- new decision knots, not new management layers.

# Phase 15 — Chapter 3: Old Burrow
- prefab mutation system;
- old-burrow landmarks;
- spatial storytelling dressing;
- final warm chamber;
- campaign completion.

# Phase 16 — Full-game Balance & Polish
- worldgen seed diversity;
- tutorial pacing;
- population/resource balance;
- audio/music;
- accessibility;
- performance;
- saves/migration;
- controller/touch as targeted.

# Phase 17 — Release Candidate
- full regression;
- platform matrix;
- save soak tests;
- random seed soak;
- release config/security/debug cleanup;
- credits/legal/license audit for all assets.

## Milestone report contract
Every phase report includes:
- exact scope;
- files changed;
- engine version;
- import/parse result;
- test count/results;
- screenshots;
- performance notes;
- known issues;
- commit ID;
- tag only if specified.
