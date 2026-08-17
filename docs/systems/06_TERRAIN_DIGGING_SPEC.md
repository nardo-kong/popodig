# 06 — Terrain & Digging Specification

**Status: LOCKED behavior categories / PROVISIONAL numeric tuning**

## 1. Purpose
Digging is the central verb. It must feel immediate to designate, satisfying to watch, strategically consequential, and technically simple enough to support large editable maps.

## 2. Cell states
Minimum logical cell state:
- Solid / Excavated
- Terrain material
- Hardness
- Dig designation state
- Active dig progress
- Feature membership
- Stability properties
- Water occupancy
- Signal values
- Zone membership if excavated

## 3. Terrain materials — V1 baseline
### Soft Soil
Fast excavation. Baseline stability.

### Clay / Damp Soil
Moderate excavation. Strong moisture visual cues. May interact with water containment tuning.

### Loose Soil
Fast/moderate excavation but lower stable span.

### Stone / Foundation
Slow excavation or contextually non-excavatable depending on content needs.

### Root-occupied Soil
Excavation behavior depends on root size. Fine roots may clear with soil; major roots become feature cells requiring route choice or a contextual action.

Keep the material set small enough that players learn silhouettes/colors quickly.

## 4. Designation UX
Supported input:
- click/tap single legal cell;
- drag/paint contiguous cells;
- optional line designation for accessibility/precision;
- cancel mode.

Rules:
- hidden inaccessible internal cells may only be designated if connected through a planned dig path or if the UX clearly shows queued dependency;
- do not allow accidental painting through protected/indestructible structures without feedback;
- invalid cells must provide immediate visual reason.

## 5. Job creation
A dig designation creates logical `DigJob` entries or a region from which executable frontier jobs are derived.

Mice may only excavate a solid cell when:
- the cell is designated;
- it is adjacent to a reachable excavated work position;
- no blocking safety rule prevents work;
- the job is not reserved by another worker beyond allowed cooperation.

## 6. Excavation progress
Recommended abstraction:
`dig_time = base_time × material_hardness × modifiers`

Avoid durability bars that turn every tile into combat. Visual progress should use cracking/crumb animation and mouse work cycles.

## 7. Multi-cell designations
The scheduler should naturally expose new executable frontier cells as earlier cells finish. The player may sketch a route without manually ordering every tile.

However, safety reactions may pause downstream queued jobs if a newly revealed hazard changes conditions.

## 8. Hazard-aware interruption
When excavation reveals:
- active water breach;
- critical instability;
- newly protected structure;

the local queued dig chain should pause where continuing would obviously worsen an emergency. The player may explicitly reprioritize after understanding the situation.

This protects autonomy without making mice appear suicidal.

## 9. Digging and topology
Digging creates permanent traversable topology. The game must account for:
- corridor width;
- room connectivity;
- mouse collision/clearance;
- travel distance;
- water routes;
- local structural span.

## 10. Tile removal presentation
A tile removal should include:
- clear mouse work animation;
- staged terrain cracking;
- small debris particles;
- short material-specific sound;
- terrain cell transition without visible seams;
- newly exposed background/wall art;
- immediate reveal signal if a feature is uncovered.

## 11. Excavated space representation
Logical foreground solid cell becomes empty traversable cavity. Use separate background/interior treatment so caves do not read as transparent holes in the world.

## 12. Backfill / rebuilding earth
**DEFERRED for V1** unless playtests prove irreversible excavation too punishing.

Players may seal openings using limited barrier/support actions; they do not freely replace arbitrary soil as a full construction mechanic.

## 13. Indestructible/protected cells
Use sparingly for:
- world bounds;
- critical foundation/landmark structures;
- explicit feature rules.

They must be visually distinguishable. Do not secretly block paths with normal-looking soil.

## 14. Dig order priority
Default priority:
- emergency context jobs;
- explicitly high-priority digs;
- normal digs by distance/availability.

The player should not manage numeric priorities per tile in normal play.

## 15. Accessibility
Provide optional:
- high-contrast designation overlay;
- signal icon overlay;
- reduced particle intensity;
- hold/confirm mode for touch to avoid accidental long drags.

## 16. Acceptance criteria
- any legal frontier can be freely designated;
- mouse autonomously reaches and digs it;
- multi-cell path unfolds correctly;
- revealing a discovery interrupts/updates local logic correctly;
- topology/pathing updates on the same or next simulation tick;
- cancelling pending jobs never corrupts cell state;
- no visual tile seams at common zoom levels.
