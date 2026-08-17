# 18 — Vertical Slice Scope & Acceptance

**Status: LOCKED scope**

## 1. Purpose
The Vertical Slice exists to prove one question:
> Is deciding where to excavate interesting enough to sustain the game when consequences permanently reshape the burrow?

It is not a content demo and not a miniature version of every future system.

## 2. Target playtime
30–45 minutes for a first-time player.

## 3. Required features
### World
- finite side-view map;
- Topsoil/Root/Moisture/weak-soil regions;
- structured seeded PCG;
- validator/repair;
- at least one Decision Knot.

### Terrain & Dig
- free single/paint dig designation;
- at least Soft Soil, Damp/Clay, Loose Soil, Stone/blocked context;
- mouse-executed excavation;
- cancellation and path updates.

### Discoveries
Exactly three major discovery families required:
1. Root Cluster
2. Water Reservoir
3. Unstable Soil

Each must implement full Signal → Reveal → Reaction → Adaptation → Stable State lifecycle.

### Colony
- 3 mice initially;
- hunger/rest/safety;
- autonomous dig/haul/emergency jobs;
- Food + General Material.

### Zones
- Sleeping
- Storage
- Food/Forage

### Environmental actions
- Seal
- Reinforce/support

### UX
- pan/zoom;
- inspect;
- dig/cancel;
- zone painting;
- context actions;
- compact HUD;
- contextual tutorial;
- debug overlays in development build.

### Persistence
- save/load;
- seed stored;
- active world state restored.

## 4. Explicitly excluded from slice
- combat;
- multiple chapters;
- Old Burrow content;
- human AI;
- technology tree;
- advanced crafting;
- complex relationships/moods;
- manual decoration;
- large content catalogue;
- infinite world.

## 5. Intended slice sequence
### Beat A — Space
Player opens a cramped start and creates first sleeping space.

### Beat B — Root clue
Food pressure + visible root gradient encourages but does not force exploration.

### Beat C — Use space
Player designates Storage/Sleeping and sees mice furnish/use it.

### Beat D — Water clue
Dampness becomes legible. Map offers enough geometry to prepare or approach directly.

### Beat E — Breach
Water forces immediate spatial reaction. Emergency hauling demonstrates colony autonomy.

### Beat F — Recovery
Player contains/reroutes water. The changed area remains useful/meaningful.

### Beat G — Instability
Valuable shortcut/deeper path crosses weak terrain. Player can detour or reinforce.

### Beat H — Stable end state
Slice ends when colony has stable food/sleep/storage and reaches a marked depth/space objective.

## 6. Functional acceptance criteria
PASS requires all:
- player can freely dig any legal frontier tile rather than choose pre-authored buttons;
- mouse AI executes designations without routine direct control;
- root/water/unstable cues appear before major consequence;
- water can be redirected by player-created topology;
- finite water is conserved;
- instability responds to excavation geometry/support;
- zones react to environmental state;
- at least one emergency produces autonomous mouse response;
- save/load restores a mid-event world safely;
- generated seeds pass validator at target success rate;
- no blocker/critical QA issue.

## 7. Design acceptance criteria
Playtest with at least several external/naive players before greenlighting content expansion.

Target observations:
- players pause before at least some digs;
- players verbally/behaviorally use clues;
- players attempt different solutions to water/instability;
- players do not all strip-mine the same shape;
- after a hazard, players adapt rather than immediately want to reload;
- players can tell a short story about why their burrow has its current shape;
- mouse autonomy feels helpful rather than opaque.

## 8. Red flags requiring redesign
- most players ignore signals;
- digging choice feels arbitrary;
- water is always solved by the same seal click;
- unstable soil is simply annoying delay;
- colony needs dominate attention;
- players spend more time managing UI than watching world;
- procedural maps frequently generate boring empty frontiers;
- hazards leave no interesting persistent result.

## 9. Visual acceptance
Screenshots must show a coherent integrated scene with:
- no asset frames/seams;
- clear topology;
- legible signals;
- readable mice;
- subtle UI;
- distinguishable water states;
- visually integrated zone dressing;
- acceptable layout at all supported slice resolutions.

## 10. Go / No-Go
Only after the Vertical Slice passes both **functional** and **design** acceptance should development expand into Chapter 2/3 content.
