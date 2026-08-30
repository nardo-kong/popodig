# Completion Report — Phase 14 Chapter 2: Adapt

## Status

**PASS.** Chapter 2 content is in the world and the water × instability
interaction is live: flooded ceilings now weaken spans (spec 09 §10 enabled),
the required reservoir has an unstable pocket directly beneath it (the two
hazards compound), water gained an elevated second reservoir that drains
through the mid-world, and foundation walls vary their authored placement.
**1164 automated assertions pass**, the 288-seed batch is **288/288 valid at
100% raw rate** (0 repairs, p95 460.51 ms), and the full `validate.ps1`
prints `VALIDATION_PASS`. Runs under the PM's end-to-end authorization.

## Scope completed

### Water × instability overlap (the Chapter 2 knot)
- `stability_system._rate_segment`: each ceiling bay standing over water
  counts **double** toward its run's effective span — a fully flooded run
  carries one band weaker (spec 09 §10's "reduce stability one band"),
  while a single wet cell only stresses its own bay. `CHANGE_WATER` joined
  the re-evaluation mask so flooding and drainage re-rate roofs live; the
  rule is fully reversible (drain the water, the warning recovers).
- Telegraphy stays inside the existing language: moisture visuals mark the
  wet cells, the standard crumb/crack/critical bands escalate on the roof,
  and the inspector stability line reflects the level.
- Worldgen: one unstable pocket is authored **directly below the required
  reservoir**, so a breach floods weak loose-soil terrain — wet bays
  escalate, and neglecting either hazard now feeds the other.
- Design note: the first cut (halving the whole run's allowed span when any
  bay was wet) collapsed 6-wide storage rooms from a single water cell and
  broke four colony-flow tests; the per-bay model keeps the rule local and
  all existing content green.

### Richer water configurations
- Second additional reservoir (config 1→2), with the first additional one
  authored **elevated in the transition band** (38–50% depth) so its breach
  drains through Chapter 2's mid-world routes; later ones stay in the wet
  stratum.

### Foundation/stone structures
- The authored foundation wall (locked decision knot: through the gap or
  over) now varies its authored ride-height per seed (high/low band), so
  the crossing plays differently across seeds without new mechanics.

### Pipe / heat / sound — intentionally not implemented
Roadmap condition "if validated" is not met: no playtest has exercised
these signals (the Phase 12 external sessions were waived by PM decision).
Recorded as open; they remain a Phase 16/17 candidate once playtests run.

### New decision knots, not new management layers
No new UI, resources, or jobs: the reservoir-over-pocket overlap and the
elevated drain route are pure spatial decisions. Chapter 2 completion in
`ChapterModel` (old-burrow depth + settled water + a completed
reinforcement) was already live from Phase 13 and now has matching content.

## Files changed

- Modified: `stability_system.gd` (per-bay wet stress + CHANGE_WATER
  re-evaluation), `structured_world_generator.gd` (overlap pocket, elevated
  reservoir, foundation height variation), `config/worldgen/default.json`
  (v5, additional_reservoirs 2), `config/app.json` (v5),
  `tests/unit/test_stability_system.gd` (wet-ceiling lifecycle test),
  `tests/unit/test_structured_worldgen.gd` (chapter-2 knot assertions)

## Godot version used

Godot 4.7.stable (unchanged).

## Import/parse status

Headless import PASS; zero parse errors.

## Automated tests

- **1164/1164 PASS** (+10: wet-ceiling lifecycle — stable→critical when
  flooded→recovers when drained — and chapter-2 knot assertions).
- 288/288 seed batch valid, **100% raw rate**, 0 repairs, 0 replay
  mismatches, p95 460.51 ms — PASS.
- Full `tools/validate.ps1`: **VALIDATION_PASS**.

## Manual/visual QA + screenshots

- Regenerated Phase 7 water captures and Phase 8 stability captures under
  the new world (validate gates green): the reservoir-over-pocket overlap is
  visible in `phase_7_reservoir_breach.png` (loose-soil fringes under the
  flood path); wet-ceiling warnings ride the existing crumb/crack visuals.
- No new screenshot gate: the overlap is content-random per seed; the
  unit/integration suites + validator guard the property.

## Performance observations

- Seed batch p95 460.51 ms (budget 600 ms), max 1078 ms — within budget.
- Runtime benchmarks unchanged (all validate gates green).

## Known deviations from spec

1. Spec 09 §10 was PROVISIONAL ("only enable if readable in playtests").
   Enabled now under the PM's end-to-end authorization with the per-bay
   local model; playtest readability is a Phase 16 checkpoint. The rule is
   config-free by design (no new knobs until validated).
2. Worldgen version bump invalidates pre-v5 saves by design (fixtures
   regenerated during validation).

## Residual risks / issues

1. Wet-ceiling escalation has no dedicated audio/visual cue beyond moisture
   visuals + standard bands; if playtests show players missing the
   water-instability link, a dedicated cue belongs in the Phase 16 polish.
2. The elevated reservoir's drain route is authored by depth band, not
   guaranteed to cross a specific decision knot; validator constraints keep
   it reachable but its dramatic overlap varies by seed.
3. Pipe/heat/sound remain unimplemented (see above).

## Completion checklist status

Phase 14 items: foundation/stone structures ✔ (authored wall ride-height
variation; the wall-with-gap knot predates this phase); richer water
configurations ✔ (elevated second reservoir); overlap water + instability ✔
(underlying pocket + per-bay wet stress); pipe/heat/sound ✔ intentionally
deferred ("if validated" unmet); new decision knots, not new management
layers ✔ (no new systems).

## Commits

- Commit A `feat:` — Phase 14 chapter 2 adapt content and wet-stability rule
- Commit B `docs:` — Phase 14 report, checklist, changelog
