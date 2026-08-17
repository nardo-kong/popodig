# 23 — Codex Execution Contract

**Status: LOCKED process contract**

## 1. Purpose
This file translates the design package into execution rules for an autonomous coding agent.

## 2. Read-before-build rule
For any task, Codex must identify the governing documents and acceptance criteria before implementation.

Do not infer genre conventions that contradict the docs.

Examples of forbidden assumptions:
- “sandbox games need crafting”;
- “colony games need mood/skills”;
- “water should be realistic”;
- “procedural world means infinite”;
- “choices should be shown as buttons.”

## 3. Task decomposition
For each milestone:
1. identify domain/data changes;
2. identify application commands/services;
3. identify presentation changes;
4. add/modify tests;
5. add debug observability;
6. execute validation;
7. perform visual QA if presentation changed.

## 4. Definition of done
A feature is done only when:
- specified behavior exists;
- failure/edge conditions handled;
- tests pass;
- debug state can be inspected;
- save implications handled;
- performance implications checked if scaling-sensitive;
- screenshots reviewed if visual;
- documentation deviations reported.

## 5. Do not hide uncertainty
If a spec leaves a value open, select a conservative provisional value in config and document it. Do not turn a tuning choice into hardcoded architecture.

If behavior is genuinely ambiguous and blocks safe implementation, report the ambiguity. If implementing end-to-end under a user instruction not to pause, choose the option that preserves the locked product principles and mark it as provisional.

## 6. Change discipline
Do not:
- rewrite architecture for style alone;
- add dependencies without need;
- add unrelated systems;
- rename core domain concepts casually;
- change save schema without versioning;
- modify worldgen behavior without updating regression tests/version as appropriate.

## 7. Test-first targets
Prefer pure deterministic tests for:
- water;
- stability;
- worldgen validators;
- signal fields;
- dig legality;
- job selection;
- save migration.

## 8. Visual QA requirement
If work changes terrain, UI, mice, features, water, signals, zones, camera, or responsiveness:
- launch the game;
- capture specified states automatically where practical;
- validate dimensions;
- inspect for blank areas, clipping, borders, seams, overlap, and state differences;
- include screenshots in completion report.

## 9. Worldgen QA requirement
If work changes generation:
- run deterministic fixture seeds;
- run batch random seeds;
- report success/failure counts;
- save failed seeds;
- report repair statistics.

## 10. Save QA requirement
If work changes any persistent domain state:
- update serializer/schema tests;
- test save/load of changed state;
- document migration requirement.

## 11. Completion report template
```md
# Completion Report — <Task/Milestone>

## Scope completed
...

## Governing specs
- ...

## Files changed
- ...

## Environment
- Godot: ...
- OS/runtime: ...

## Import / parse
PASS/FAIL + details

## Automated tests
- Total: ...
- Passed: ...
- Failed: ...

## Scenario / seed tests
- ...

## Visual QA
- Screenshot path — WIDTHxHEIGHT — state
- ...

## Performance
...

## Spec deviations
None / ...

## Known issues and residual risks
...

## Git
- Commit: ...
- Tag: ... / not required

## Recommendation
PASS / CONDITIONAL PASS / FAIL
```

## 12. Milestone gate
If working milestone-by-milestone, stop after the report and wait for approval. Do not automatically implement the next milestone unless explicitly instructed to execute the entire project continuously.
