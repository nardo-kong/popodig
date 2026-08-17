# 16 — Performance & Scalability Budget

**Status: PROVISIONAL targets / LOCKED profiling discipline**

## 1. Performance philosophy
Optimize the systems that scale with map size or agent count. Do not prematurely micro-optimize presentation before profiling.

## 2. Target baseline
**PROVISIONAL:**
- desktop: stable 60 FPS at normal gameplay zoom;
- mid-range mobile: stable 30–60 FPS depending on device/profile;
- no multi-second simulation hitch from a normal excavation/water/collapse event;
- world generation acceptable behind a loading screen and instrumented.

Exact hardware matrix to be defined before release QA.

## 3. Main scaling risks
- one Node per cell;
- full-map signal recalculation;
- full-map water scan every tick;
- full A* rebuild per mouse per frame;
- repeated zone flood fills;
- excessive particles/audio emitters;
- save serialization of verbose objects;
- debug overlays left active in release.

## 4. Terrain budget
Logical cells live in arrays/chunks. Rendering uses TileMapLayer or batched equivalents.

No persistent per-solid-cell Node architecture.

## 5. Signal budget
Signals update on generation and dirty-region events. Cache bands/values.

Instrument:
- cells recomputed;
- milliseconds per update;
- dirty region size.

## 6. Water budget
Maintain active wet regions/cell queues.

Stable pools sleep until topology/source changes.

Instrument:
- active water cells;
- transfers per tick;
- tick duration;
- max queue length.

## 7. Stability budget
Only recalculate local dirty regions after excavation, support change, root modification, collapse, or relevant wetness change.

## 8. Mouse/path budget
Pathfind only when:
- job acquired;
- target changes;
- path invalidated;
- danger requires escape.

Cache/reuse path topology data where practical.

## 9. Update staggering
Low-priority needs/idle logic may be staggered across frames/ticks. Do not evaluate every mouse's full utility list every render frame.

## 10. Visual culling
Offscreen:
- stop nonessential mouse detail animation if safe;
- cull particles;
- reduce localized audio;
- do not instantiate unnecessary decoration detail.

Simulation must remain logically correct.

## 11. Memory
Track:
- grid bytes/cell;
- feature data;
- save state size;
- texture memory;
- active mouse/job allocations.

Avoid duplicating full-sized field arrays if a compact representation is sufficient.

## 12. Worldgen budget
Record stage timings:
- skeleton
- strata
- landmark
- feature
- terrain
- signal
- validation
- repair

Keep seed/regression reports.

## 13. Performance test scenarios
- large excavated burrow with many visible cavities;
- 20+ mice or chosen final cap stress case;
- major water breach;
- multiple active wet regions;
- repeated local collapses;
- maximum zoomed-out map view;
- rapid dig painting/cancel;
- save during mature world;
- debug disabled release build.

## 14. Regression gate
A milestone cannot be marked complete if it introduces a persistent major frame-time or simulation-tick regression without documenting/approving it.
