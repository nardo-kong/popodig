# 28 — Open Decisions & Playtest Questions

**Status: OPEN — Codex must not silently lock these**

These questions should be implemented with configurable defaults, then decided from prototype/Vertical Slice evidence.

## O-001 Final art rendering mode
Options:
- true pixel art;
- pixel-inspired higher-resolution 2D.

Need test:
asset-generation consistency, tile seam quality, mobile/desktop scaling, mouse animation workload.

## O-002 Final cell visual size
Logical grid is fixed conceptually, but pixels-per-cell should be chosen after camera/readability tests.

## O-003 Full-world dimensions
Choose after measuring traversal, zoom, save size, worldgen quality, and chapter pacing.

## O-004 Mouse population cap
Need test for readability, path performance, and whether additional mice create useful spatial pressure.

## O-005 Time controls
**PROVISIONAL implementation (2026-10-22, #19):** clickable 1×/2×/3× and
pause, Tab to cycle, danger onset returns to 1× with an explicit notice.
Simulation still uses fixed 0.05-second steps; wall/active telemetry stays
real time. Default speed resets to 1× on load. Both speed availability and
danger slowdown are configurable in `config/balance/core.json`.
Player preference and emergency readability still need observation.

## O-006 Seasonal pressure exact form
Could be:
- broad winter progress bar;
- chapter milestones with seasonal presentation;
- very forgiving timer.

Must not create high-frequency schedule management.

## O-007 Water cell capacity and transfer rate
Tune for readable flow and enough reaction time.

## O-008 Shallow-water traversal threshold
Need animation/readability test.

## O-009 Stability span thresholds
Tune so topology matters without constant collapse micromanagement.

## O-010 Root cutting/removal
Whether major roots can be removed at all in V1. Preserve-only/route-around may be cleaner if cutting creates too many secondary dependencies.

## O-011 Damp/Wet room modifiers
Determine whether Damp is merely preference or invalidity for specific zones.

## O-012 Population growth fiction
Milestone arrivals, family growth abstraction, or other lightweight explanation. Do not build reproduction simulation to answer this.

## O-013 Mobile in first slice
Decide based on current product priority. Architecture/input abstraction must remain touch-compatible regardless.

## O-014 Endgame sandbox continuation UX
Determine whether completion transitions to pure sandbox immediately or offers a continue button/epilogue summary.

## O-015 Human structure feature depth
Warm pipe/foundation sounds may enter Chapter 2 only if they add a clear spatial rule and do not inflate art/system scope.

## Decision method
For each open item:
1. define two or three minimal variants;
2. expose tuning/config flag where practical;
3. test against core product metrics;
4. record decision in `00_DECISION_REGISTER.md` once resolved.
