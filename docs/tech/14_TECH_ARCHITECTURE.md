# 14 — Technical Architecture

**Status: LOCKED architecture principles / PROVISIONAL class names**

## 1. Baseline
- Engine: Godot 4.7 stable
- Language: GDScript
- Rendering: 2D
- Simulation: tile/cell grid
- Source control: Git
- External QA helpers: Python 3.x allowed for screenshot/image/report tooling

## 2. Architectural rule
Simulation truth lives in data/services, not in scene-node transforms.

A tile is not “solid” because a Sprite exists. A mouse is not “hungry” because an animation is playing. Presentation reflects simulation state.

## 3. Recommended project structure
```text
project.godot
AGENTS.md
assets/
  art/
  audio/
  fonts/
config/
  balance/
  worldgen/
data/
  features/
  strata/
scenes/
  app/
  world/
  entities/
  ui/
src/
  domain/
    world/
    colony/
    jobs/
    features/
  application/
    commands/
    services/
    orchestration/
  infrastructure/
    save/
    config/
    telemetry/
  presentation/
    world/
    entities/
    ui/
    debug/
tests/
  unit/
  integration/
  fixtures/
tools/
  qa/
  worldgen/
```

## 4. Core domain model
### WorldGrid
Owns map dimensions and cell data.

### CellData
Plain logical state, preferably compact and serialization-friendly.

### FeatureRegistry
Owns `DiscoveryFeature` instances and feature metadata.

### WorldGenerator
Runs deterministic pipeline and validation.

### SignalSystem
Builds/updates signal fields in dirty regions.

Current Phase 6 implementation stores Root Density and Moisture as compact `WorldGrid` fields. Generation replaces each complete field in one operation; runtime terrain mutations recalculate bounded regions, retain a capped dirty-region history for diagnostics, and dirty only affected presentation chunks. Player-facing queries return qualitative bands/wording, while raw values remain development-overlay data.

### DigSystem
Validates designations, creates executable dig jobs, resolves tile excavation.

### WaterSystem
Moves discrete water units on scheduled ticks.

The Phase 7 implementation owns finite reservoir lifecycle state and a deterministic active-cell simulation. Each excavated cell holds 0–4 units; a bounded fixed step prefers gravity, then horizontal movement toward lower fill. Sources, terrain changes, and seals wake only local cells, while unchanged pools sleep after a configurable quiet window. `get_conserved_inventory()` treats standing water plus remaining finite reserves as one audited quantity.

`SealSystem` is a separate adaptation service. It converts a player request into an autonomous colony job, consumes exactly one General Material at completion, displaces any shallow water before closing the cell, and commits the seal through the packed cell flag so path, zone, water, checksum, and later save systems share one truth. A completed seal remains removable through the dominant DIG verb.

### StabilitySystem
Evaluates dirty local structural regions and resolves warning/collapse.

### ZoneSystem
Owns room zone data and suitability.

### JobSystem
Creates, scores, reserves, and completes colony work.

### MouseSystem / MouseAgent
Maintains mouse needs, current job, pathing, emergency states.

### ProgressionSystem
Tracks knowledge states, chapter milestones, and campaign completion.

### SaveService
Serializes world and runtime state with schema versioning.

## 5. Application layer
Player input should produce commands rather than mutate arbitrary nodes.

Examples:
- `DesignateDigCommand(cells)`
- `CancelDigCommand(cells)`
- `AssignZoneCommand(zone_type, cells)`
- `PlaceSealCommand(cell)`
- `PlaceSupportCommand(cell)`

Commands validate against domain rules and return structured result/rejection reasons.

## 6. Simulation tick strategy
Do not tie all gameplay behavior directly to frame rate.

Recommended:
- render/process: frame-based;
- mouse movement interpolation: frame/physics process;
- needs/jobs: low-frequency simulation tick;
- water: fixed lower-frequency tick or event-driven active-region tick;
- stability: event/dirty-region recalculation;
- signals: event/dirty-region recalculation;
- worldgen: offline/loading-time pipeline.

## 7. Cell storage
Avoid one Node per terrain cell.

Use arrays/chunk data:
- packed arrays, typed arrays, or custom chunk resources;
- separate frequently changed dynamic data where useful;
- TileMapLayer/presentation generated from logical state.

## 8. Chunks
Even with a finite world, divide simulation/presentation into chunks for dirty updates and rendering organization.

**PROVISIONAL:** 16×16 or 32×32 cells per chunk.

Chunk owns dirty flags such as:
- terrain visual dirty;
- signal dirty;
- water active;
- stability dirty;
- path topology dirty.

## 9. Rendering layers
Suggested scene/presentation stack:
1. background/earth depth backdrop
2. excavated cavity background
3. terrain solids via TileMapLayer(s)
4. signal overlays integrated with terrain
5. water
6. feature sprites/tiles
7. zone dressing/items
8. mice
9. job/designation overlays
10. VFX
11. UI/debug

## 10. Pathfinding
Use `AStarGrid2D` or a custom grid path service if dynamic update performance/behavior requires it.

Requirements:
- solid cells blocked;
- full/deep water blocked;
- shallow water weighted;
- collapsed rubble state handled;
- topology updates after excavation/collapse/seal.

For larger worlds, update local points/regions rather than rebuild every frame.

## 11. World generation architecture
Use pure/testable generation stages where practical.

Suggested interfaces:
```text
WorldGenConfig
WorldGenContext
IWorldGenStage.run(context)
WorldValidator.validate(context) -> ValidationReport
WorldRepairer.repair(context, report)
```

Persist a generation report for debug builds.

## 12. Feature architecture
Prefer data-driven feature definitions with script behaviors.

Feature definition fields may include:
- ID/type
- generation parameters
- signal configuration
- reveal rules
- reaction handler
- stable-state tags
- art/audio IDs
- validator constraints

Avoid hardcoding all root/water logic in a single world controller.

Phase 6 keeps Root lifecycle behavior in `RootFeatureSystem`, separate from generation geometry and presentation. It subscribes to authoritative `DigSystem.cell_excavated`, enforces a one-shot reveal/reaction, advances monotonic recognition, exposes a finite food reserve, and reaches Stable State only through a valid set-up nearby Food/Forage zone. This is the reference contract for later Water and Stability feature handlers.

Phase 7 follows the same contract in `WaterSystem`: Moisture clues precede reveal; authoritative excavation fires a one-shot breach reaction; finite discharge changes the continuous map; player-created drainage, storage relocation, and `SealSystem` barriers are spatial adaptations; exhausted, unchanged pools enter Stable State and sleep. Breach danger uses the existing mouse interruption path. A mouse already inside the danger region may path outward, and resumes ordinary autonomy after reaching a safe cell so a persistent pool cannot permanently pause the colony.

## 13. Event bus
Use explicit domain/application signals/events for cross-system reactions.

Examples:
- `cell_excavated`
- `feature_revealed`
- `water_region_changed`
- `stability_warning_changed`
- `zone_invalidated`
- `mouse_in_danger`
- `chapter_milestone_reached`

Avoid a global untyped event soup. Keep event contracts documented/typed.

## 14. Debug tooling
Required debug capabilities:
- regenerate seed;
- copy seed;
- reveal all terrain/features;
- toggle each signal overlay;
- water-unit overlay;
- stability overlay;
- mouse path/job visualization;
- force time/speed;
- teleport camera to landmark/event;
- run validator report;
- capture deterministic screenshots.

## 15. Configuration
Move tunable values out of scripts into version-controlled config/resources:
- dig hardness/time;
- mouse need rates;
- job scoring weights;
- water capacity/rate;
- stability spans;
- signal thresholds;
- worldgen ranges;
- zone suitability.

## 16. Determinism
Strict lockstep determinism is not required, but deterministic seeds/tests are desirable.

Never rely on unseeded global randomness for world generation. Runtime cosmetic randomness should be separated from simulation randomness where feasible.

## 17. Error handling
Domain command failures return reason codes, e.g.:
- NOT_EXCAVATABLE
- NOT_REACHABLE
- PROTECTED_FEATURE
- INVALID_ZONE_CELL
- INSUFFICIENT_MATERIAL
- HAZARD_LOCKED

Normal expected rejection must not spam error logs.

## 18. Logging
Debug logs should include categories:
`WORLDGEN`, `DIG`, `WATER`, `STABILITY`, `JOB`, `MOUSE`, `SAVE`, `QA`.

Release builds suppress verbose simulation logging.

## 19. Dependency direction
Presentation may depend on application/domain APIs.
Domain must not depend on UI scenes.
Save adapters may know serialized forms but should not become gameplay authority.

## 20. Architecture acceptance
Before content expansion, prove:
- simulation can run headless enough for tests;
- a seeded world generates without rendering;
- terrain changes update presentation independently;
- save/load reconstructs the same logical state;
- debug overlays read domain state rather than duplicate calculations.
