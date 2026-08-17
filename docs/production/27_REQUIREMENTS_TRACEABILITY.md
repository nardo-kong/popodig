# 27 — Requirements Traceability Matrix

**Status: ACTIVE**

This matrix prevents core design intentions from disappearing during implementation.

| ID | Requirement | Authority | Primary implementation | Primary verification |
|---|---|---|---|---|
| RQ-001 | Player can freely designate any legal frontier tile | Decision D-001/D-003 | DigSystem + input commands | Dig integration tests + playtest |
| RQ-002 | No A/B route-choice UI as core exploration | D-001 | UX | UI review |
| RQ-003 | Space differs via Information/Value/Risk/Cost/Topology | D-002 | Worldgen + features | Seed review + playtest |
| RQ-004 | Frontier produces meaningful decisions | D-004 | Worldgen Decision Knots | Validator + playtest |
| RQ-005 | Major features follow discovery grammar | D-005 | Feature architecture | Feature-specific tests |
| RQ-006 | Hidden features leak qualitative signals | D-006 | SignalSystem | Signal tests + usability |
| RQ-007 | Hazards usually create stable opportunities | D-007 | Feature designs | Scenario/playtest |
| RQ-008 | Physics remains tile-level/intuitive | D-008 | Water/Stability | Architecture review |
| RQ-009 | Water finite and topology-sensitive | D-009 | WaterSystem | Conservation/topology tests |
| RQ-010 | Collapse local and telegraphed | D-010 | StabilitySystem | Bounded-collapse tests |
| RQ-011 | World finite and continuous | D-011 | WorldGrid/Worldgen | Generation tests |
| RQ-012 | Structured generation pipeline | D-012 | WorldGenerator | Stage reports/tests |
| RQ-013 | Semi-authored PCG | D-013 | Landmarks/prefabs | Seed inspection |
| RQ-014 | Mice autonomous | D-014 | Job/Mouse systems | AI scenario tests |
| RQ-015 | Minimal mouse needs | D-015 | Mouse state | Scope/code review |
| RQ-016 | Player zones spaces, no core manual furnishing | D-016 | ZoneSystem | UX/playtest |
| RQ-017 | Resource vocabulary stays small | D-017 | Inventory/balance | Scope review |
| RQ-018 | No combat in V1 | D-018 | Project scope | Repository review |
| RQ-019 | Story stays under one house/garden | D-019 | World/narrative | Content review |
| RQ-020 | 3-phase campaign | D-020 | Progression | Scenario tests |
| RQ-021 | Concrete final-home objective | D-021 | Progression | Campaign QA |
| RQ-022 | Player knowledge is progression | D-022 | Recognition/UI | Playtest |
| RQ-023 | Godot 4.7 + data/presentation separation | D-023 | Tech architecture | Build/code review |
| RQ-024 | Slice contains Root/Water/Unstable only as major discoveries | D-024 | Slice content | Scope audit |
| RQ-025 | New features justify dig decision value | D-025 | Production process | PM/content review |

## Maintenance rule
When a locked decision is changed:
1. amend Decision Register;
2. update impacted specs;
3. update this matrix;
4. update tests/acceptance criteria;
5. note migration/save/worldgen consequences.
