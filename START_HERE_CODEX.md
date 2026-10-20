# START HERE — Codex Implementation Entry Point

## Current work: Dig Down 2.0
Start with `docs/design/DIG_DOWN_2_0_DESIGN.md` and
`docs/production/DIG_DOWN_2_0_EXECUTION.md`, then GitHub tracking issue #1.
The owner authorized continuous implementation and core/incremental tests per
issue, with broad regression at batch boundaries. The V1 instructions below
remain useful background where they do not conflict with this 2.0 baseline.

You are implementing **Dig Down / 地下鼠鼠** from this documentation repository.

## Step 1 — Read authority docs
Read in this order:
1. `AGENTS.md`
2. `docs/product/00_DECISION_REGISTER.md`
3. `docs/product/01_PRODUCT_VISION.md`
4. `docs/design/02_GDD.md`
5. `docs/design/03_CORE_LOOP_PROGRESSION.md`
6. all system/world/tech specs relevant to the current milestone
7. `docs/qa/17_TEST_QA_PLAN.md`
8. `docs/production/19_IMPLEMENTATION_ROADMAP.md`

## Step 2 — Do not redesign the game
The product is already defined. In particular:
- free digging is mandatory;
- choices emerge spatially, never as repeated A/B prompts;
- DIG is the dominant verb;
- PCG is finite, structured, validated, and repairable;
- water is finite tile-level simulation;
- collapse is local;
- mice are autonomous;
- simulation must remain simpler than Terraria/Noita/ONI-style full-system scope;
- combat, deep crafting, skill trees, infinite world, and heavy colony needs are out of V1.

## Step 3 — Implement by milestone
Use `docs/production/19_IMPLEMENTATION_ROADMAP.md`.

### Recommended PM-gated mode
Implement one phase, validate it, return the required completion report, and wait for approval.

### Continuous mode
If the user explicitly asks for the entire project in one run, continue through milestones but still create an internal gate report after each phase and stop expanding content if a gate fails. Do not hide failed acceptance criteria by moving on.

## Step 4 — Quality contract
For every phase:
- implement smallest spec-compliant behavior;
- add tests;
- expose debug observability;
- run import/parse;
- run automated tests;
- perform visual QA when presentation changes;
- report performance when relevant;
- commit with a meaningful message.

## Step 5 — Vertical Slice is the product gate
Do not expand Chapters 2–3 merely because engineering works. The Vertical Slice must satisfy `docs/qa/18_VERTICAL_SLICE_ACCEPTANCE.md`, especially the design question:

> “I can dig anywhere, but I care where I dig next.”

If this is not true in playtesting, iterate the core loop first.
