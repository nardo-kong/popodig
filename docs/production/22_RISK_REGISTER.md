# 22 — Product & Technical Risk Register

**Status: ACTIVE**

## R1 — Free digging becomes meaningless strip-mining
**Probability:** High
**Impact:** Critical

Mitigation:
- strong signal/value/risk/cost/topology gradients;
- travel and stability consequences;
- validator-created Decision Knots;
- playtest before content expansion.

Trigger:
Players routinely paint huge rectangles without inspection.

## R2 — Game becomes arbitrary RNG
**Probability:** Medium
**Impact:** Critical

Mitigation:
- Signal Fields;
- fairness rules;
- deterministic feature logic;
- partial inference before consequence.

Trigger:
Players describe hazards as “random” despite repeated exposure.

## R3 — Water simulation scope explosion
**Probability:** High
**Impact:** High

Mitigation:
- finite discrete tile water;
- limited flow rules;
- active-region updates;
- explicit rejection of pixel physics.

Trigger:
Implementation discussions require pressure, viscosity, per-pixel materials, or full fluid solver.

## R4 — Colony AI becomes main game
**Probability:** Medium
**Impact:** High

Mitigation:
- minimal needs;
- autonomous jobs;
- no detailed schedules/skills;
- player manages space/priorities only.

Trigger:
Players spend more attention on pawn panels than frontier.

## R5 — Procedural generation creates boring maps
**Probability:** High
**Impact:** High

Mitigation:
- structured pipeline;
- authored landmarks/prefabs;
- validators/repair;
- Decision Knots;
- curated regression seeds.

Trigger:
Large portions of play are empty identical digging.

## R6 — AI-generated art does not integrate
**Probability:** High
**Impact:** High

Mitigation:
- art bible;
- tile/pixel density authority;
- asset pipeline with cleanup;
- in-engine screenshot approval;
- seam/border checks.

Trigger:
Assets look good individually but game reads as collage/stickers.

## R7 — Hazards are punishment, not opportunity
**Probability:** Medium
**Impact:** High

Mitigation:
- stable-state requirement;
- multiple adaptations;
- recoverable first encounters;
- zone/environment benefits after resolution.

Trigger:
Players reload immediately after water/collapse instead of adapting.

## R8 — One optimal rectangular base emerges
**Probability:** Medium
**Impact:** High

Mitigation:
- irregular landmarks/features;
- room suitability;
- topology/travel cost;
- finite obstacles;
- seed variation.

Trigger:
Experienced players reproduce the same room block regardless of seed.

## R9 — Visual signals are unreadable
**Probability:** Medium
**Impact:** Critical

Mitigation:
- art hierarchy;
- icon accessibility overlay;
- signal threshold tests;
- close/normal/zoomed-out QA.

Trigger:
Naive players cannot predict root/water above chance.

## R10 — Dynamic pathing performance
**Probability:** Medium
**Impact:** Medium/High

Mitigation:
- grid pathfinding;
- local updates;
- path only on demand;
- bounded mouse count;
- performance scenario tests.

## R11 — Save complexity from mutable world
**Probability:** Medium
**Impact:** Critical

Mitigation:
- versioned schema;
- save actual state;
- atomic writes;
- fixtures/migrations;
- no node-path identity.

## R12 — Scope grows through “expected sandbox features”
**Probability:** High
**Impact:** Critical

Mitigation:
Apply scope question:
> Does it make the next excavation decision more interesting?

Combat, crafting trees, professions, factions, detailed furniture remain deferred unless core loop proves need.

## R13 — Chapters feel like reskinned layers
**Probability:** Medium
**Impact:** High

Mitigation:
Each chapter introduces a new rule/relationship, not merely art/material.

## R14 — Too much simulation is hidden
**Probability:** Medium
**Impact:** Medium

Mitigation:
Only simulate intuitive visible consequences. Provide inspector/debug tooling.

## R15 — Touch input conflicts with free painting/camera
**Probability:** Medium if mobile
**Impact:** High

Mitigation:
Dedicated gesture state machine; touch-specific QA; paint lock/hold thresholds; no blind mouse-event mapping.

## R16 — Story scope expands beyond production capacity
**Probability:** Medium
**Impact:** Medium/High

Mitigation:
First game stays beneath one house/garden; old civilization becomes small Old Burrow traces; narrative primarily environmental.
