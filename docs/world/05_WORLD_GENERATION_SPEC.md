# 05 — World Generation Specification

**Status: LOCKED pipeline / PROVISIONAL algorithms and values**

## 1. Goal
Generate worlds that feel natural and replayable while guaranteeing meaningful spatial decisions, solvability, and chapter content.

The generator must produce game design, not merely random terrain.

## 2. Determinism
Given the same:
- game version/worldgen version;
- seed;
- generation configuration;

the world should be reproducible where practical.

Store seed and worldgen version in saves.

## 3. Pipeline
### Stage 1 — World Skeleton
Create map dimensions, surface profile, starting burrow, depth ranges, chapter target bands, and protected margins.

### Stage 2 — Strata
Assign broad material/environment distributions with irregular boundaries.

### Stage 3 — Landmarks
Place guaranteed macro features using placement constraints and minimum/maximum distances.

### Stage 4 — Feature Graph
Place major Root Clusters, Water Reservoirs, Rock Masses, Natural Cavities, Unstable Pockets, foundation structures, and later Old Burrow prefabs.

### Stage 5 — Terrain Fill
Resolve cell material and hardness around feature geometry.

### Stage 6 — Signal Fields
Calculate hidden/visible qualitative fields such as moisture, root density, instability indicators, heat, and sound.

### Stage 7 — Validation
Run automated gameplay constraints.

### Stage 8 — Repair
Move, resize, add, remove, or reconnect limited features until constraints pass or generation is rejected/retried.

## 4. Data layers
Recommended generator layers:
- `terrain_material`
- `excavatable`
- `feature_owner_id`
- `stratum_id`
- `moisture_field`
- `root_signal_field`
- `stability_base`
- `heat_signal_field` (later)
- `sound_signal_field` (later)
- `landmark_mask`
- `protected_mask`

## 5. Noise usage
Noise may be used for:
- irregular stratum edges;
- stone/clay patches;
- minor hardness variation;
- art variation indices;
- noncritical micro-shapes.

Noise must not independently determine:
- whether the first food source exists;
- whether the player can progress;
- whether the first reservoir destroys the starting burrow;
- the existence of chapter landmarks;
- the presence of meaningful decision frontiers.

## 6. Major feature generation
### 6.1 Root Cluster
Generate from one or more anchors with branching paths. A cluster owns cells and emits a distance/density signal.

Guarantees:
- first useful root is reachable in Chapter 1;
- not directly adjacent to start so the player learns to read a gradient;
- at least two reasonable approach geometries when possible.

### 6.2 Water Reservoir
Generate a bounded water-bearing cavity or porous pocket with finite reserve.

Guarantees for first reservoir:
- moisture cues extend toward reachable frontier;
- direct breach is disruptive but recoverable;
- at least one plausible mitigation topology exists nearby;
- cannot immediately flood all start critical zones without warning.

### 6.3 Unstable Pocket
Generate a bounded weak-material area with visible precursor cues.

Guarantees:
- not required as an unavoidable lethal corridor;
- valuable enough to tempt approach or create a useful shortcut;
- support/detour strategies both remain plausible.

### 6.4 Natural Cavity
Use shape templates/noise cleanup. Cavities may create shortcuts and room opportunities, but should not trivialize excavation progression.

### 6.5 Old Burrow
Use authored prefabs plus controlled mutation:
- mirror;
- limited rotation if projection permits;
- seal some entrances;
- collapse selected internal cells;
- vary dressing/feature links.

Do not generate old burrows as pure random walkers if resulting topology is consistently poor.

## 7. Decision Knot generation
A **Decision Knot** is a local region where multiple frontier directions have meaningfully different signatures.

Candidate recipe:
- one value signal (e.g. root);
- one risk/opportunity signal (e.g. moisture);
- one high-cost route (e.g. hard rock);
- one lower-information safe route.

The player is never forced to use these exact options; the knot simply creates unequal space.

### Target density
**PROVISIONAL:** major early play should encounter a new meaningful knot roughly every 5–10 active minutes, adjusted by dig speed and map scale.

## 8. Validation rules
The generator must check at minimum:

### Start safety
- start burrow has legal sleeping/storage candidates;
- no active water enters start at frame 0;
- starting mice have traversable floor/space.

### Food viability
- a food opportunity exists within an acceptable early dig-cost envelope.

### Progress path
- chapter target bands are not completely sealed by indestructible cells.

### Hazard recoverability
- first required hazard interaction has at least one feasible response using unlocked tools.

### Landmark reachability
- all required landmarks have at least one potential excavation route.

### Frontier quality
- early world contains at least one validated Decision Knot.

### Topology sanity
- no required area exists only through a 1-cell impossible passage for mouse collision dimensions;
- no disconnected required prefab due to terrain fill.

## 9. Repair strategies
Repair should be minimal and deterministic where possible:
1. carve/soften a limited corridor;
2. move a feature within its legal placement region;
3. resize a reservoir/pocket;
4. add signal exposure;
5. insert a small natural cavity;
6. relocate optional rock mass;
7. regenerate local chunk;
8. reject seed as last resort.

## 10. Debug outputs
Worldgen debug mode must support overlays for:
- strata;
- feature IDs;
- all signal fields;
- predicted reachable region;
- landmarks;
- Decision Knots;
- validator failures/repairs.

Provide seed copy/replay controls.

## 11. Test seeds
Maintain a curated set:
- `seed_smoke_default`
- `seed_water_close`
- `seed_root_complex`
- `seed_unstable_route`
- `seed_old_burrow_mutation`
- several randomly captured regression seeds.

## 12. Versioning
Any algorithm change that alters generated topology should increment `worldgen_version` and preserve old saves by storing generated world state rather than regenerating a live save from seed alone.
