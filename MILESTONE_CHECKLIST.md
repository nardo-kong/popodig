# Dig Down — Milestone Checklist

## Phase 0 — Foundation
- [x] Godot 4.7 project created
- [x] Repository/folder architecture
- [x] Test runner
- [x] Validation script
- [x] Debug/release flags
- [x] Screenshot helper
- [x] Smoke tests PASS

## Phase 1 — Grid World
- [x] WorldGrid/CellData
- [x] Chunk model
- [x] Terrain rendering
- [x] Camera
- [x] Seeded simple world
- [x] Debug inspector
- [x] Performance baseline

## Phase 2 — Digging
- [x] Dig paint/click
- [x] Cancel
- [x] Legality/frontier
- [x] Dig jobs
- [x] Mouse excavation
- [x] Topology update
- [x] Path update
- [x] Dig QA PASS

## Phase 3 — Colony
- [x] 3 mice
- [x] Hunger
- [x] Rest
- [x] Safety interruption
- [x] Job reservations
- [x] Hauling
- [x] Food + Material
- [x] Soak test PASS

## Phase 4 — Zones
- [x] Sleeping
- [x] Storage
- [x] Food/Forage
- [x] Suitability
- [x] Auto setup/dressing placeholder
- [x] Zone edit/reassign

## Phase 5 — World Generation
- [x] Skeleton
- [x] Strata
- [x] Landmarks
- [x] Features
- [x] Terrain fill
- [x] Signals hook
- [x] Validate
- [x] Repair
- [x] Batch seed report

## Phase 6 — Root
- [x] Root geometry
- [x] Root signals
- [x] Reveal
- [x] Reaction
- [x] Adaptation
- [x] Stable state
- [x] Food integration
- [ ] Playtest cue readability

## Phase 7 — Water
- [x] Finite reservoir
- [x] Moisture signal
- [x] Tile flow
- [x] Breach
- [x] Seal
- [x] Emergency haul
- [x] Wet zone state
- [x] Stable pool sleep
- [x] Conservation tests

## Phase 8 — Stability
- [x] Weak soil
- [x] Local span rules
- [x] Warning bands
- [x] Reinforcement
- [x] Collapse
- [x] Topology update
- [x] Bounded-collapse tests

## Phase 9 — Slice UX
- [x] HUD
- [x] Inspector
- [x] Context tutorial
- [x] Notifications
- [x] 30–45 min flow
- [ ] Touch pass if scoped

## Phase 10 — Persistence/Hardening
- [x] Save schema (v2, docs/tech/15)
- [x] Atomic saves (temp file + rename, corruption preserved as .corrupt)
- [x] Mid-event save/load (water-breach fixture + Phase 10 smoke)
- [x] Migration framework (sequential v1→v2 chain)
- [x] Regression suite (984 assertions, validate.ps1 gates)
- [x] Performance profile (build ≈5 ms, write ≈20 ms, load ≈0.5 s)

## Phase 11 — Art/Audio Integration
- [x] Locked render mode/scale
- [x] Terrain transitions
- [x] Mouse animation set
- [x] Root complete states
- [x] Water complete states
- [x] Stability complete states
- [x] Zone dressing
- [x] Audio/VFX
- [x] Visual QA PASS

## Phase 12 — Vertical Slice Gate
- [ ] Functional acceptance PASS
- [ ] External/naive playtests
- [ ] Players use signals
- [ ] Multiple valid solutions observed
- [ ] Hazards cause adaptation, not reload
- [ ] Burrows show spatial stories
- [ ] GO / ITERATE / PIVOT decision recorded

## Phase 13–15 — Full Campaign
- [ ] Chapter 1 complete
- [ ] Chapter 2 complete
- [ ] Chapter 3 Old Burrow complete
- [ ] Final warm-home objective
- [ ] Post-completion sandbox

## Phase 16–17 — Release
- [ ] Balance
- [ ] Accessibility
- [ ] Platform QA
- [ ] Save soak
- [ ] Seed soak
- [ ] Performance
- [ ] Asset license audit
- [ ] Debug cleanup
- [ ] Release Candidate regression PASS
