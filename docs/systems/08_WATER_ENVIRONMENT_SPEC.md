# 08 — Water & Environment Specification

**Status: LOCKED abstraction / PROVISIONAL unit counts and rates**

## 1. Design goal
Water must create understandable spatial consequences and memorable recoverable accidents without requiring fluid-dynamics simulation.

## 2. Representation
Each excavated cell may hold discrete `water_units` from 0 to `CELL_WATER_CAPACITY`.

**PROVISIONAL:** capacity 4 units for simple visual states:
- 0 dry
- 1 shallow
- 2 low
- 3 high
- 4 full

Internal units may be higher if needed for smoother behavior, while presentation remains banded.

## 3. Water sources
### Finite Reservoir — V1 standard
A feature stores a finite `reserve_units`. When breached, units enter connected excavated cells until reserve is exhausted or blocked.

### Replenishing Source
**DEFERRED / content-specific.** Never introduce implicitly.

## 4. Flow rules
At a fixed simulation interval:
1. Prefer transferring water downward into available capacity.
2. Then transfer horizontally toward lower-filled adjacent cells.
3. Optional limited upward equalization is allowed only if needed to approximate connected water level and remains intuitive.
4. Water never moves through solid or sealed barrier cells.

The algorithm must be deterministic enough for test fixtures.

## 5. Scope control
- Update only active wet regions and neighboring cells.
- Cap iterations/work per tick.
- Dormant stable pools do not require continuous expensive recomputation.
- Mark a region dirty when terrain/barriers change.

## 6. Breach event
When a reservoir boundary is excavated:
- play breach feedback;
- mark nearby mice in danger-awareness state;
- begin reservoir discharge;
- pause obviously dangerous queued local excavation;
- create high-priority emergency haul jobs for vulnerable food/material where configured.

## 7. Player responses
### Dig drainage route
Create a lower path/cavity so gravity redirects water.

### Prepare sump/pool
Excavate a low cavity before breach.

### Seal
Use General Material to block a local opening. Seal rules must be simple and visible.

### Relocate zone
Move Storage/Sleeping away from wet area.

### Accept wet zone
Allow stable water to remain and use the surrounding area for content that benefits from moisture.

## 8. Environmental wetness
Do not run full humidity simulation.

Derive a qualitative local state from nearby standing water or wet feature cells:
- Dry
- Damp
- Wet

Room suitability uses these states.

## 9. Zone effects
### Storage
Strong penalty/invalid when persistently Wet or flooded.

### Sleeping
Prefer Dry. Damp may reduce quality/efficiency but should not create detailed disease simulation.

### Food/Forage
Some future food features may prefer Damp/Wet conditions.

## 10. Mouse-water interaction
V1 mice do not need full swimming AI.

Recommended rules:
- shallow water remains traversable with movement penalty;
- high/full water becomes nontraversable or danger state;
- mice avoid routes expected to become unsafe where possible;
- trapped mice seek nearest safe reachable cell.

Exact thresholds are playtest tuning.

## 11. Visuals
Use tile/cell-aligned water surfaces with smoothing/edge sprites where possible.

Required readability:
- water depth state;
- flow direction during active movement;
- reservoir breach source;
- wet/damp terrain cues.

Do not attempt Noita-like per-pixel material simulation.

## 12. Audio
- breach splash;
- short active trickle/flow loop near camera;
- calm pool ambience optional;
- muffled damp signal before reveal.

## 13. Test cases
Automated fixtures:
- vertical shaft drains downward;
- basin fills before overflow;
- two connected basins equalize within tolerance;
- seal blocks flow;
- finite reservoir eventually exhausts;
- newly dug lower path redirects existing wet region;
- save/load preserves units and stable state;
- large stable pool respects update budget.

## 14. Failure boundaries
Water must not:
- teleport across solids;
- disappear without a documented sink;
- multiply from finite reservoirs;
- permanently soft-lock mandatory progression without an available recovery tool;
- require exact numeric micromanagement from player.
