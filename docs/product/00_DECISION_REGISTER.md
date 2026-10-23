# 00 — Decision Register

**Status: LOCKED unless explicitly amended**

This document records decisions that govern all lower-level design and implementation.

## D-001 Product form
**Decision:** Dig Down is a free-digging systemic sandbox, not a route-choice game.

**Implication:** The player may designate any legal excavatable tile. UI must never reduce exploration to repeated A/B choice prompts.

## D-002 Source of meaningful choice
**Decision:** Choices emerge from five spatial gradients:
1. Information
2. Value
3. Risk
4. Cost
5. Topology

**Implication:** World generation and content placement must create unequal frontiers rather than force doors or dialogue choices.

## D-003 Core player verb
**Decision:** DIG remains the dominant player action from minute 1 through the endgame.

Supporting verbs may include designate zone, prioritize, seal, reinforce, and inspect. No supporting verb may require more attention than digging in normal play.

## D-004 Decision Frontier
**Decision:** The boundary between excavated space and unknown terrain is the primary decision surface.

A good world continuously presents several frontier segments with different signals and consequences.

## D-005 Discovery grammar
**Decision:** Important underground content follows:
**Signal → Reveal → Reaction → Adaptation → Stable State.**

This is the standard content contract for roots, water, unstable soil, pipes, old burrows, and future discoveries.

## D-006 Unknown information
**Decision:** Unknown terrain is partially inferable, not pure hidden RNG.

Signals should become stronger with proximity or relevance. Exact values are usually hidden.

## D-007 Hazard philosophy
**Decision:** Major hazards should usually create a short-term disruption and a long-term spatial opportunity.

Examples:
- water can flood storage, then become a useful pool/wet zone;
- collapse can block a corridor, then create or expose a cavity;
- root systems can obstruct digging, then provide food/support.

Pure punishment is reserved for clear, telegraphed player overreach.

## D-008 Simulation abstraction
**Decision:** Simulate only phenomena that players can understand from visible behavior.

Use tile-level water, local stability, simple environment states, discrete resources, and explicit connectivity. Do not implement high-fidelity physics merely because it is technically possible.

## D-009 Water model
**Decision:** Water uses finite tile-level units that primarily move downward and secondarily equalize sideways. Water sources have finite reserves unless a future content spec explicitly defines a replenishing source.

## D-010 Stability model
**Decision:** Collapse is local, rule-based, telegraphed, and bounded. There is no global stress simulation.

## D-011 World form
**Decision:** Initial product uses a finite, continuous vertical world rather than an infinite world.

Players may revisit all previously excavated areas. Chapters are depth/content phases, not separate levels.

## D-012 World generation
**Decision:** Generation pipeline is:
**World Skeleton → Strata → Landmarks → Features → Terrain → Signal Fields → Validate → Repair.**

Noise is cosmetic/local variation, not the game-design layer.

## D-013 Authored + procedural mix
**Decision:** Use semi-procedural generation.

Macro guarantees and key landmarks are authored as rules/templates; local positions, shapes, blockages, and microterrain vary by seed.

## D-014 Colony control
**Decision:** Mice are autonomous workers. The player controls priorities and spaces, not individual movement in normal play.

## D-015 Mouse simulation scope
**Decision:** V1 mouse needs are deliberately minimal: hunger, rest, danger response, and work availability. Complex psychology, relationships, diseases, and skill trees are deferred.

## D-016 Room interaction
**Decision:** The player designates room/zone purposes; mice furnish and use them automatically. Manual furniture placement is not a core V1 mechanic.

## D-017 Resource scope
**Decision:** V1 uses a small resource vocabulary. Food and General Material are the baseline. Additional resources require a clear decision-loop purpose.

**2.0 owner revision (2026-10-21):** Food, building materials, stone, ore,
metal and collectibles support exploration, light production and spatial
planning. Use stable IDs and preserve/migrate old Food/General Material.
See `docs/design/DIG_DOWN_2_0_DESIGN.md`; no individual equipment or deep recipes.

## D-018 Combat
**Decision:** Combat is deferred from the initial product. Threat should primarily alter space, timing, access, or resources rather than create a combat subsystem.

## D-019 Story scale
**Decision:** The first complete game occurs beneath one old house and its garden. The scale does not expand into subway megastructures or ancient empires in V1.

## D-020 Three-part progression
**Decision:**
1. **Settle / 安家** — learn digging, rooms, roots, basic signals.
2. **Adapt / 适应地下** — water, unstable soil, human foundation/pipes, stronger consequences.
3. **Old Burrow / 旧鼠穴** — reuse existing spaces, traces of prior mice, final stable warm home.

## D-021 End goal
**Decision:** The campaign has a concrete seasonal/home goal rather than “build forever”: establish a stable deep home before harsh conditions fully arrive. Sandbox continuation after completion is allowed.

## D-022 Progression philosophy
**Decision:** Player knowledge is a major progression vector. Repeated encounters improve the clarity of cues and the player's own understanding; upgrades should not replace learning.

**2.0 owner revision (2026-10-21):** Shared colony capabilities earned through
resources/production open further exploration alongside signal knowledge.
No individual mouse inventory, tools or equipment management. The approved
loop includes discovery rewards, light production, logistics and collectibles.

## D-023 Technical baseline
**Decision:** Godot 4.7 stable, 2D grid simulation, deterministic seeded generation where feasible, data/presentation separation, versioned saves, automated tests, screenshot-based visual QA.

## D-024 Vertical Slice scope
**Decision:** The first proof is a 30–45 minute slice with only three major discoveries:
- Root Cluster
- Water Reservoir
- Unstable Soil

If these do not produce meaningful “where do I dig next?” decisions, more content must not be added to mask the problem.

## D-025 Scope gate
Any proposed feature must answer:
> “How does this make the next excavation decision more interesting?”

If it cannot, it is non-core and should normally be deferred.
