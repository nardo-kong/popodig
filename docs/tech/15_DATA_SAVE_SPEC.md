# 15 — Data Model & Save Specification

**Status: LOCKED versioning / PROVISIONAL exact serialization format**

## 1. Goals
- reliable persistence of modified terrain;
- reproducible debugging;
- migration-ready saves;
- compact enough for finite world;
- no dependency on scene-tree node paths as save identity.

## 2. Save header
Minimum:
```json
{
  "save_schema_version": 1,
  "game_version": "...",
  "worldgen_version": 1,
  "seed": 12345,
  "created_at": "...",
  "last_saved_at": "..."
}
```

## 3. World state
Persist actual generated/mutated state, not only seed.

Need:
- dimensions;
- terrain material per cell;
- excavated state;
- water units;
- rubble/support/seal state;
- protected/landmark references;
- feature IDs/states;
- zone IDs;
- active/pending designations if desired.

Use chunked/RLE/packed representation if size requires optimization.

## 4. Feature state
Each feature:
```text
feature_id
feature_type
definition_version
geometry/cell references
revealed_state
reaction_state
stable_state
runtime values (e.g. reservoir reserve)
```

Do not derive a partially consumed reservoir solely from the original seed.

## 5. Mouse state
Persist:
- mouse ID/name/cosmetic seed;
- position/safe fallback cell;
- hunger/rest;
- carried inventory;
- current high-level state.

Recommendation: rebuild path and possibly job reservation on load rather than serializing fragile path internals.

## 6. Inventory
Persist global/logical counts and item stacks/cell storage if physical hauling representation requires it.

## 7. Zones
Persist:
- zone ID;
- type;
- cell membership;
- dressing seed/config;
- stored references where applicable.

## 8. Jobs
Pending player designations should persist. Runtime reservations/in-progress jobs may be reconstructed deterministically from designations and world state on load if simpler and safer.

Document whichever strategy is implemented.

## 9. Progression
Persist:
- chapter;
- objectives/milestones;
- feature recognition levels;
- tutorial flags;
- seasonal progress;
- completion state.

## 10. Settings
User settings should be separate from per-save world state where practical.

## 11. Autosave
**PROVISIONAL:**
- autosave at safe intervals and chapter milestones;
- do not save every water tick;
- avoid saving during partially applied atomic world changes;
- optional rotating autosave slots.

## 12. Atomicity
Use temporary file + replace/rename or engine-safe equivalent so an interrupted write does not destroy the only save.

## 13. Migration
Every schema-breaking change increments `save_schema_version`.

Implement sequential migration functions:
`v1 -> v2 -> v3` rather than scattered compatibility checks.

## 14. Corruption recovery
On load failure:
- report user-readable failure;
- preserve corrupted file for debug if possible;
- offer most recent valid autosave;
- do not silently generate a new world under the same save identity.

## 15. Test fixtures
Maintain committed save fixtures for:
- new game;
- after root reveal;
- active water breach;
- post-collapse;
- multiple zones/mice;
- end-of-slice;
- prior schema versions when migrations exist.

## 16. Save/load acceptance
After save/load, verify:
- terrain topology identical;
- water totals conserved;
- feature reveal/reserve state identical;
- zones intact;
- mice recover safely;
- progression unchanged;
- no duplicate jobs/items/features.
