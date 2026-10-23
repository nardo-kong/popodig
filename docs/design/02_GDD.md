# 02 — Game Design Document (GDD)

> **2.0 execution authority:** Read `docs/design/DIG_DOWN_2_0_DESIGN.md` for the current loop: visible promise → discovery → resources/collection → hauling/production → home planning → shared capability → deeper exploration. Production zones, multiple purposeful resource types and colony capability stages supersede corresponding V1 limits below. Initial population is one, with chapter growth.

**Status: Core LOCKED / values PROVISIONAL**

## 1. Game overview
Dig Down is a side-view 2D underground systemic sandbox about a small mouse colony building a home by freely excavating a finite vertical world beneath an old house and garden.

The central tension is simple:
> Every legal tile can be dug, but not every direction is equally wise.

The player's main interaction is spatial designation. Mice autonomously execute work and inhabit resulting spaces.

## 2. Camera and world presentation
- Fixed 2D cross-section perspective.
- World reads like a living ant-farm cutaway.
- Camera pans and zooms across a continuous map.
- Surface remains spatially connected to deep areas.
- Unknown terrain is visible as material mass, but hidden features are inferred through signals.
- Excavated cavities remain visible and persistent.

## 3. Primary verbs
### 3.1 Dig Designation
Paint/click excavatable cells or a contiguous area. A work order enters the colony job queue.

### 3.2 Cancel Designation
Remove pending dig orders that have not begun.

### 3.3 Inspect
View visible information about terrain, signals, room suitability, water, stability, and known features.

### 3.4 Zone
Assign excavated spaces as Sleeping, Storage, Food/Forage, or later chapter-specific uses.

### 3.5 Priority
Mark a small number of jobs/areas as urgent. This changes job ordering, not direct mouse control.

### 3.6 Seal / Reinforce
Contextual environmental actions unlocked when required. They exist to modify consequences, not to become a full building game.

## 4. Core loop
1. Observe current colony needs and frontier signals.
2. Infer likely value/risk around available frontier segments.
3. Designate excavation freely.
4. Mice travel and dig.
5. New terrain/feature is revealed.
6. A reaction may occur: water movement, instability warning, cavity opening, root exposure.
7. Player adapts through routing, zones, sealing, reinforcement, or further excavation.
8. Mice settle into the new stable configuration.
9. New needs/frontiers emerge.
10. Repeat.

## 5. Decision Frontier
The current boundary between excavated and unexcavated cells is a gameplay surface.

A healthy frontier contains multiple segments that differ by:
- signal strength;
- expected value;
- hazard likelihood;
- digging time/material hardness;
- connectivity and travel distance;
- future room shape.

The game should not explicitly score these alternatives. The player learns to read them.

## 6. Spatial economy
Space is the main strategic currency.

Excavated space can be:
- useful but distant;
- safe but poorly shaped;
- wet and unsuitable for food storage;
- well connected but vulnerable to a breach;
- naturally supported by roots/rock;
- cheap to excavate but topology-poor.

The player optimizes a living shape, not a spreadsheet.

## 7. Resources
### 7.1 Food
Consumed by mice. Obtained from early root/forage features and chapter-specific opportunities.

### 7.2 General Material
Abstract building/support material used for sealing, reinforcement, and automatic zone dressing.

V1 avoids multiple ore tiers and large crafting chains.

## 8. Rooms / zones
Zones are applied to excavated connected cells.

Initial types:
- **Sleeping Area** — rest; prefers dry, calm, reasonably warm/safe space.
- **Storage Area** — holds Food/Material; strongly dislikes flooding.
- **Food/Forage Area** — interfaces with edible roots/food features or simple preparation.

Future zone types are allowed only when they create new spatial tradeoffs.

Mice automatically place visual dressing/proxy furnishings within valid zones.

## 9. Mouse colony
### 9.1 Initial population
Vertical Slice: 3 mice.
Campaign may expand gradually, with a conservative cap chosen for readability/performance.

### 9.2 Needs
- Hunger
- Rest
- Safety state / danger interruption

### 9.3 Work
- Dig
- Haul
- Emergency haul
- Seal/reinforce
- Zone setup/maintenance

### 9.4 Autonomy
Mice pick reachable jobs based on urgency, distance, need pressure, and job type. Player does not normally select a mouse and click a destination.

## 10. Discovery objects
Every major discovery is authored using five stages:

1. **Signal** — visible/audible precursor in still-hidden terrain.
2. **Reveal** — excavation exposes the object/state.
3. **Reaction** — immediate consequence.
4. **Adaptation** — player has multiple spatial responses.
5. **Stable State** — discovery remains a persistent part of the map.

### Root Cluster
- Signal: fine roots become denser.
- Reveal: thick root structure/food-bearing section.
- Reaction: obstruction + food opportunity.
- Adaptation: route around, cut selected roots if allowed, zone nearby, preserve support.
- Stable State: forage/support landmark.

### Water Reservoir
- Signal: dampness gradient, droplets/soil darkening.
- Reveal: finite water pocket breached.
- Reaction: water moves into lower connected excavated cells.
- Adaptation: trench, sump, seal, relocate storage, accept wet zone.
- Stable State: contained pool/wet area.

### Unstable Soil
- Signal: crumb texture, cracks, falling particles.
- Reveal: low-support cavity/weak material becomes structurally relevant.
- Reaction: warning state; local cells may collapse if span/rules are exceeded.
- Adaptation: narrow excavation, reinforce, create alternative route, intentionally trigger controlled collapse.
- Stable State: supported route, blocked area, or new cavity.

## 11. Information model
Signals are qualitative in normal UI.

Examples:
- moisture: none / faint / noticeable / strong
- root: none / threads / dense threads / major root nearby
- instability: stable / crumbs / cracking / critical
- heat/sound: introduced in later chapters

Exact hidden coordinates or percentages are not normally shown.

## 12. Failure and recovery
V1 avoids hard game-over from one unlucky excavation.

Failure pressure may include:
- food loss;
- temporarily unusable rooms;
- blocked paths;
- mice forced to relocate;
- material consumption;
- lost time before seasonal objective.

Hard failure should require accumulated neglect or clearly telegraphed risky behavior.

## 13. Chapter goals
### Chapter 1 — Settle
Establish dry sleeping, reliable food access, and basic storage; learn signals and free digging.

### Chapter 2 — Adapt
Reach deeper foundation zone while managing water and unstable terrain; repurpose environmental discoveries.

### Chapter 3 — Old Burrow
Find and rehabilitate remnants of a prior mouse burrow; establish the final stable warm home before seasonal pressure peaks.

## 14. Campaign completion
Completion is achieved when the colony meets a set of final-home stability conditions in the deep warm area. The player may continue sandbox play afterward.

## 15. Difficulty philosophy
Difficulty should arise from interacting spatial constraints, not opaque stat inflation.

Increase challenge by:
- longer travel distances;
- tighter topology;
- overlapping signals;
- larger/less convenient features;
- stronger consequences;
- competing room suitability;
- seasonal timing pressure.

Avoid merely increasing dig HP and resource costs.

## 16. Non-goals
The GDD explicitly excludes for V1:
- combat loop;
- weapon/equipment progression;
- deep crafting;
- economic trading;
- manual furniture decorator as a required system;
- NPC factions;
- procedural quests unrelated to excavation;
- unlimited material catalogue;
- realistic bodily simulation.
