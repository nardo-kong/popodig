# 09 — Stability & Collapse Specification

**Status: LOCKED local model / PROVISIONAL thresholds**

## 1. Design goal
Excavation shape should matter, especially in weak terrain, without simulating real geotechnical stress.

## 2. Principle
Stability is local, legible, and bounded.

Players should understand:
- narrow openings are safer;
- weak soil gives more warning;
- major roots/rock/supports can improve local stability;
- an overwide unsupported span may collapse.

## 3. Cell properties
Solid terrain may define:
- base stability class;
- support strength;
- collapse susceptibility;
- feature modifiers.

Excavated cells may reference nearby ceiling/support topology.

## 4. Suggested model
For each dirty local region, evaluate excavated roof cells/unsupported spans using simple neighborhood rules.

Example abstraction:
- Soft Soil: supports moderate span.
- Loose Soil: supports short span.
- Stone: high stability.
- Root-supported: bonus near major roots.
- Reinforcement: explicit local support bonus.

Do not calculate global load paths.

## 5. Warning stages
1. Stable
2. Crumbs / subtle dust
3. Cracks / audible creak
4. Critical warning
5. Local collapse

The player must have reaction time except for deliberately ignored critical states or explicitly scripted tutorial-safe microcollapse.

## 6. Collapse behavior
A collapse affects a bounded cluster around unstable roof cells.

Effects may:
- fill excavated cells with rubble/loose terrain;
- block routes;
- displace/damage stored goods lightly;
- interrupt mouse jobs;
- expose adjacent hidden cavity/feature in authored cases.

Avoid long cascading whole-map collapse in V1.

## 7. Adaptation options
- narrow the planned excavation;
- stop digging and route around;
- reinforce using General Material;
- create support pillar by leaving solid cells;
- intentionally trigger/clear a small collapse where beneficial.

## 8. Stable state
A resolved unstable area should remain visibly legible:
- supports;
- rough rubble boundary;
- deliberately narrow passage;
- newly opened cavity.

## 9. Root interaction
Major root cells may count as natural local support. Cutting/removing them can reduce stability only where clearly telegraphed.

Avoid creating hidden dependencies that punish players long after a root is removed.

## 10. Water interaction
**PROVISIONAL:** Wet/loose soil may reduce stability one band locally. Keep interaction simple and only enable if readable in playtests.

## 11. Mouse safety
Mice should avoid entering a critical-warning tile cluster for normal jobs. Emergency pathing may route away automatically.

Direct mouse death from a first-time collapse is not required in V1.

## 12. Test cases
- stable span remains stable;
- weak over-span enters warning then collapses;
- reinforcement prevents collapse;
- root support modifier applies locally;
- collapse updates pathfinding;
- collapse cannot escape configured max radius;
- save/load preserves rubble and supports.
