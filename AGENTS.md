# AGENTS.md — Dig Down / 地下鼠鼠

## 0. Current 2.0 execution authority (2026-10-22)
Read `docs/design/DIG_DOWN_2_0_DESIGN.md` and
`docs/production/DIG_DOWN_2_0_EXECUTION.md` before implementing current work.
They record the owner's approved design discussion and supersede conflicting
V1 resource/progression limits below. The original two ChatGPT download files
were not committed; these are explicitly sourced execution specifications,
not a claim to have recovered those files.

The owner explicitly authorized continuous implementation of GitHub #1–#15 and the experience/packaging follow-ups #17–#21.
Claim the next dependency-ready issue and continue after reporting/checking a
batch; do not stop for repeated milestone approval. Human observations must
remain marked pending until actually performed.

Testing cadence requested by the owner: run core invariants and affected
incremental suites per issue, plus import/parse and focused gameplay smoke
when appropriate. Run broad regression only after a batch of related issues
or when a new failure/risk warrants it. Do not repeat the full 288-seed matrix
or every screenshot pipeline after small changes. Record the exact selection,
result, commit and remaining human gates.

## 1. Role
You are implementing the game described by this repository. Treat the Markdown specifications in `docs/` as the product authority. Do not silently redesign mechanics, invent substitute systems, or broaden scope because a familiar genre usually contains them.

## 2. Authority order
When documents conflict, use this order:
1. `docs/product/00_DECISION_REGISTER.md`
2. `docs/product/01_PRODUCT_VISION.md`
3. `docs/design/02_GDD.md`
4. system-specific specifications under `docs/systems/` and `docs/world/`
5. technical specifications under `docs/tech/`
6. UX/art/QA/production documents
7. implementation convenience

Report any unresolved contradiction before changing behavior.

## 3. Locked product principles
- This is a **free-digging systemic sandbox**, not an A/B choice game.
- Player freedom is real: any legal excavatable tile may be designated for digging.
- Decisions emerge from unequal space: information, value, risk, cost, and topology.
- The primary player verb is **DIG**. Any feature that weakens DIG as the dominant verb requires explicit approval.
- Unknown terrain leaks partial information through **Signal Fields**; it is not pure hidden RNG.
- Major underground content uses the same lifecycle: **Signal → Reveal → Reaction → Adaptation → Stable State**.
- Hazards should usually become long-term opportunities after short-term disruption.
- The player assigns space and priorities; mice execute work autonomously.
- The game does not become a high-micromanagement colony simulator.
- Physics is tile-level and intuitive. Do not implement pixel fluids, full structural mechanics, CFD, realistic thermodynamics, or soil engineering.
- World generation is structured PCG: **World Skeleton → Strata → Landmarks → Features → Terrain → Signal Fields → Validate → Repair**.
- Noise may add natural variation; noise must never replace game-design structure.
- The initial product is finite-world, chapter-progressive, spatially continuous. Do not implement an infinite world unless explicitly approved.

## 4. Locked exclusions for V1
Do not add without explicit approval:
- combat
- weapons
- hostile faction simulation
- deep crafting trees
- technology tree
- individual mouse skill trees
- dozens of needs/moods
- realistic temperature/gas simulation
- pixel-level water simulation
- procedural infinite worlds
- complex production chains
- manual furniture placement as a core loop
- event-card A/B decisions replacing spatial decisions

## 5. Technical baseline
- Engine: Godot 4.7 stable.
- Primary language: GDScript unless a document explicitly specifies otherwise.
- 2D tile-based logical world.
- Separate simulation/data state from presentation nodes.
- Deterministic seeded world generation where practical.
- Save files must be versioned and migration-ready.
- Automated tests are required for deterministic systems.
- Visual QA screenshots are required for milestone acceptance.

## 6. Implementation discipline
Before coding a milestone:
1. Read the relevant specs and acceptance criteria.
2. List assumptions that are not specified.
3. Prefer the smallest implementation satisfying the specification.
4. Keep simulation logic testable without requiring rendered scenes where possible.
5. Add tests in the same change as the behavior.
6. Run validation before reporting completion.

Do not refactor unrelated systems while implementing a milestone unless necessary to satisfy architecture constraints.

## 7. Required completion report
Every implementation task must return:
- Scope completed
- Files changed
- Godot version used
- Import/parse status
- Automated tests run and pass/fail counts
- Manual/visual QA performed
- Screenshots produced, with dimensions
- Performance observations if relevant
- Known deviations from spec
- Residual risks/issues
- Commit ID
- Tag, if the milestone explicitly requires one

A task is not complete when code merely compiles; it is complete when its acceptance criteria pass.

## 8. Stop conditions
Return completion evidence after each batch. For the current 2.0 run, the
owner's explicit end-to-end authorization in §0 applies: continue through
dependency-ready issues, keeping genuine human playtest gates open.
