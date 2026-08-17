# 17 — Test & QA Plan

**Status: LOCKED quality gates / PROVISIONAL tooling details**

## 1. QA philosophy
The project contains procedural generation and interacting simulation. Manual play alone is insufficient. Every deterministic subsystem needs automated coverage, and every visual milestone needs screenshot review in-engine.

## 2. Test layers
### Unit tests
Pure/small systems:
- grid coordinate helpers;
- dig legality;
- job scoring/reservation;
- signal falloff;
- water transfer;
- stability rules;
- zone suitability;
- save migrations.

### Integration tests
System interactions:
- dig -> reveal -> signal/feature update;
- dig -> water breach -> path invalidation -> emergency jobs;
- dig -> stability warning/collapse -> topology update;
- zone -> storage -> flood -> emergency haul;
- worldgen -> validation -> repair.

### Scenario tests
Deterministic seeded gameplay fixtures with expected invariants.

### Visual QA
Automated screenshots + image checks + human review.

### Performance tests
Instrumentation and benchmark scenarios from performance spec.

## 3. Mandatory smoke tests
Every meaningful build:
- project imports/parses without errors;
- main scene launches;
- seeded world generates;
- mouse spawns and idles;
- legal dig can be designated/completed;
- path updates after dig;
- save/load smoke passes;
- debug UI absent in release configuration.

## 4. Worldgen property tests
Run many seeds and assert:
- start valid;
- required landmark counts;
- first food reachable;
- required depth path possible;
- no out-of-bounds features;
- reservoirs have positive finite reserve;
- Decision Knot requirement where configured;
- validation/repair converges below retry limit.

Record failed seeds automatically.

## 5. Water invariants
- total water = remaining source reserves + water in cells + documented sinks;
- no transfer through solids/seals;
- no negative/overcapacity cell;
- stable state eventually sleeps;
- deterministic fixture outputs within accepted order rules.

## 6. Stability invariants
- collapse radius bounded;
- protected/indestructible cells never collapse unless explicitly allowed;
- support can only improve/maintain expected local score;
- topology/pathing dirty flags fire after collapse.

## 7. Mouse/job invariants
- a mouse cannot own two exclusive jobs;
- a reserved item is not double-hauled;
- unreachable job does not create an infinite selection loop;
- danger interruption clears/reassigns job safely;
- no mouse remains permanently inside a newly solid/rubble cell after recovery logic.

## 8. Save invariants
- load does not duplicate entities/features/items;
- water conserved;
- zones match cell membership;
- world dimensions/version correct;
- corrupt save failure is handled without overwrite;
- migration fixtures remain loadable.

## 9. Visual test matrix
At minimum:
### Resolutions/aspects
- 1280×720
- 1920×1080
- 2560×1440 if available
- portrait/mobile target such as 390×844 if mobile is in current build scope
- representative tablet aspect if targeted

### Scenes/states
- initial burrow
- dig designation
- root weak/strong/revealed
- water signal/breach/flow/stable pool
- instability warning/collapse/reinforced
- zone edit and normal view
- zoomed-out mature burrow
- debug overlays
- release clean UI

## 10. Automated image checks
Python QA may check:
- screenshot dimensions;
- blank/empty large regions;
- UI clipping;
- overlap of critical HUD regions;
- unintended solid borders/frames around sprites;
- state screenshots differ when expected;
- alpha/edge artifacts for imported assets where feasible.

Automated image checks supplement, not replace, visual review.

## 11. Seed replay QA
Bug reports involving world logic must include:
- seed;
- save or exact action sequence;
- game/worldgen version;
- screenshot/video where relevant.

## 12. Acceptance report format
Every milestone report includes:
- build/engine version;
- commit;
- tests passed/failed counts;
- scenario seeds;
- screenshot list and dimensions;
- performance observations;
- deviations;
- known issues;
- recommendation: PASS / CONDITIONAL PASS / FAIL.

## 13. Severity
### Blocker
Crash, save corruption, cannot progress, deterministic generator failure at high rate.

### Critical
Major system rule broken, unavoidable unfair hazard, severe visual/input failure.

### Major
Noticeable logic/UX issue with workaround.

### Minor
Polish/cosmetic issue not impairing core understanding.

## 14. Release gate
No release candidate with:
- known save-corruption blocker;
- frequent generator softlock;
- core water/stability invariant failure;
- input unusable on a supported platform;
- visible debug UI/log spam;
- unresolved major asset seam/border issue in primary gameplay.
