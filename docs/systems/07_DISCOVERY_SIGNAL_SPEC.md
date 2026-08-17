# 07 — Discovery & Signal Field Specification

**Status: LOCKED architecture / PROVISIONAL thresholds**

## 1. Purpose
Unknown terrain must support inference. Signals convert hidden features from arbitrary RNG into spatial information without revealing exact answers.

## 2. Core content contract
Every major `DiscoveryFeature` must define:
1. Hidden geometry/state
2. Signal emitters/field rules
3. Reveal trigger
4. Immediate reaction
5. Player adaptation affordances
6. Stable persistent state
7. Visual/audio presentation
8. Validator constraints

## 3. Signal principles
- Signals are strongest near relevant hidden geometry.
- Signals may be directional or irregular.
- Signals should overlap occasionally to create ambiguity.
- Normal UI presents qualitative information.
- Debug UI exposes exact field values.
- Signals should be learnable through repeated cause/effect.

## 4. Baseline signal channels
### Moisture
Source: water-bearing features.
Presentation: darker soil, sheen, droplets, soft damp sound.

### Root Density
Source: root feature cells/anchors.
Presentation: fine root threads increasing in density/diameter.

### Instability
Source: weak soil geometry and local excavation state.
Presentation: crumbs, microcracks, falling particles, creaks.

### Heat — Chapter 2/3
Source: warm pipe/final warm region if used.
Presentation: subtle color/particle/ambient clues, not numeric temperature simulation.

### Sound/Vibration — Chapter 2/3
Source: human structures/pipes/large cavity cues if used.
Presentation: periodic low-intensity audio and small terrain reaction.

## 5. Field calculation models
Use the cheapest model matching the feature:

### Distance falloff
For compact features:
`signal = max(0, strength - distance × falloff)`

Distance may use Manhattan, Euclidean approximation, or weighted grid distance.

### Propagated field
For signals affected by material/connectivity, perform bounded flood-fill/Dijkstra from emitters with attenuation.

### Authored mask
For prefabs/landmarks, signal values may be authored as masks and transformed with the prefab.

Do not run expensive full-map recalculation every frame.

## 6. Update timing
Signal fields primarily update when:
- world generation completes;
- relevant terrain is excavated/changed;
- source state changes;
- a local feature is added/removed.

Use dirty regions/chunks.

## 7. Player knowledge states
A feature category may have recognition levels:
- `UNKNOWN`
- `ENCOUNTERED`
- `UNDERSTOOD`

These levels affect explanation/UI wording, not hidden physics.

Example moisture:
- UNKNOWN: “The soil looks unusual.”
- ENCOUNTERED: “This soil is damp.”
- UNDERSTOOD: “Damp soil often means water is nearby.”

Avoid exact “3 tiles to reservoir” unless accessibility/debug mode requires it.

## 8. Signal readability thresholds
Each signal channel should map internal values to 3–4 presentation bands. Thresholds are tunable and tested on actual art.

The player should normally be able to distinguish:
- no meaningful signal;
- weak hint;
- obvious clue;
- near/immediate warning.

## 9. Overlap behavior
When two signals overlap:
- do not blend into unreadable noise;
- prioritize distinct visual modalities where possible (e.g. root line art + damp color);
- inspector may list multiple qualitative clues.

## 10. Reveal rules
A feature becomes known when:
- one of its cells is excavated/exposed; or
- a specific feature-defined boundary condition occurs.

On reveal:
- update knowledge state;
- trigger reaction;
- play strong but brief feedback;
- update map/inspector.

## 11. Fairness rules
A major harmful reaction must have at least one of:
- clear strong pre-signal;
- small first consequence with time to respond;
- prior tutorialized rule;
- optional player overcommit that caused the scale.

Do not create invisible instant colony-destroying features.

## 12. Content examples
### Root Cluster
Signal emitter: root geometry.
Signal: visible fine roots through soil.
Reveal: major root surface exposed.
Reaction: obstruction/food node activation.
Stable state: persistent root landmark.

### Water Reservoir
Signal emitter: reservoir boundary/porous halo.
Signal: dampness field.
Reveal: breach cell opens.
Reaction: finite water units enter connected cavity.
Stable state: contained/redistributed water.

### Unstable Pocket
Signal is partly dynamic: base weak soil + current unsupported span.
Reveal is not a one-time surprise; warnings intensify as excavation changes local stability.
Reaction: bounded local collapse if critical state persists/expands.

## 13. Debug requirements
Overlay toggles:
- each raw signal field heatmap;
- qualitative threshold bands;
- emitters;
- dirty regions;
- feature IDs;
- player recognition state.

## 14. Acceptance criteria
- players can infer first root/water encounters above chance in usability tests;
- signals update after terrain changes;
- no exact hidden geometry leaks in normal view;
- overlapping signals remain legible;
- discovery reaction fires once unless feature explicitly supports repeated events.
