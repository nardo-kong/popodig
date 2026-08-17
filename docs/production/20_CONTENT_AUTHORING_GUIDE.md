# 20 — Content Authoring Guide

**Status: LOCKED content grammar / PROVISIONAL examples**

## 1. Purpose
New content should expand the existing spatial language instead of creating disconnected mini-games.

Before adding any feature, answer:
> How does this make the next excavation decision more interesting?

## 2. Discovery Feature template
Every new feature specification must include:

### Identity
- Feature ID
- Player-facing name
- Chapter/depth availability
- Rarity/placement role

### Hidden geometry
- shape family;
- size range;
- placement constraints;
- interaction with strata/landmarks.

### Signal
- channel;
- field shape/falloff;
- visual bands;
- audio reinforcement;
- recognition wording.

### Reveal trigger
Exactly what excavation/exposure changes it from hidden to known?

### Immediate reaction
What changes in the next seconds/minute?

### Adaptation options
At least two meaningfully different spatial responses where possible.

### Stable state
What remains in the map after the immediate problem is resolved?

### Spatial value
How can it improve/alter:
- rooms;
- paths;
- food/material access;
- safety;
- environment;
- chapter progress?

### Failure/fairness
What warning prevents arbitrary punishment?

### Validation rules
What conditions must worldgen guarantee?

### Art/audio states
List all required production states.

### Test cases
List deterministic fixtures/invariants.

## 3. Example: Warm Pipe
**Chapter:** Adapt

Signal:
- faint warmth field;
- periodic hum/vibration.

Reveal:
- player exposes pipe/foundation interface.

Reaction:
- pipe becomes a protected obstacle; nearby area gains Warm suitability tag.

Adaptation:
- route around;
- create sleeping space nearby;
- use pipe as one side of a corridor boundary;
- avoid noisy section if noise mechanic is active.

Stable state:
- permanent warm landmark.

Why it belongs:
It changes excavation route and room suitability without adding a new management dashboard.

## 4. Example: Natural Cavity
Signal:
- small falling grains / hollow sound near thin wall.

Reveal:
- excavation opens a pre-existing cavity.

Reaction:
- sudden large space and possible topology shortcut.

Adaptation:
- use as room;
- route through;
- seal if it connects an unsafe wet/unstable region.

Stable state:
- persistent geometry.

## 5. Bad feature examples
### “Iron Ore” whose only purpose is currency
Reject unless material creates a spatial decision beyond more resource value.

### Random event card: “A flood happens. Pay 10 material?”
Reject. It bypasses spatial simulation and player-created topology.

### New mouse profession with 8 stat modifiers
Reject for V1 unless it directly solves a proven spatial problem better than existing priorities.

### Decorative biome with no mechanical difference
Low priority. Visual variety alone cannot carry chapter progression.

## 6. Decision Knot authoring template
A Decision Knot should combine 2–4 competing properties, e.g.:
- strong root signal upward;
- moisture signal downward;
- hard rock on right;
- safe soft soil on left.

Do not wall the player into four corridors. Leave free-dig geometry around the knot.

## 7. Prefab rules
Authored structures such as Old Burrow pieces should provide:
- connector sockets;
- protected cells;
- mutation masks;
- signal/feature anchors;
- dressing anchors;
- validator metadata.

Procedural mutation may block/remove noncritical parts but must preserve required connector logic.

## 8. Content budget discipline
Before adding a new system, prefer adding:
- a new configuration of existing features;
- overlapping signals;
- new topology;
- a new stable-state use;
- a new authored landmark.

The game's depth should come from combinations, not the number of independent systems.
