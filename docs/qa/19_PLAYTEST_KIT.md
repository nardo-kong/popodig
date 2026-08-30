# 19 — Vertical Slice Playtest Kit

**Status: Phase 12 gate support (docs/qa/18_VERTICAL_SLICE_ACCEPTANCE.md)**

Phase 12 is a decision gate, not an implementation milestone. The GO /
ITERATE / NO-GO call belongs to the PM, informed by external naive playtests.
This kit packages everything needed to run those sessions and to record the
functional acceptance evidence.

## 1. Functional acceptance checklist (spec §6)

Run the automated gates first (`tools/validate.ps1` must print
`VALIDATION_PASS`), then confirm each criterion against the evidence below.

| # | Criterion (spec §6) | Evidence |
|---|---------------------|----------|
| 1 | Free dig on any legal frontier tile | `tests/unit/test_dig_system.gd`, `tests/integration/test_mouse_dig_flow.gd`; in-game: paint dig anywhere reachable |
| 2 | Mouse AI executes without direct control | `tests/integration/test_colony_simulation.gd`, phase 3 smoke; in-game: designate and watch |
| 3 | Root/water/unstable cues precede consequences | phase 6/7 smokes + `phase_6_root_clues.png`, `phase_7_moisture_clues.png`, `phase_8_stability_warnings.png` |
| 4 | Water redirected by player topology | `tests/integration/test_water_colony_flow.gd`, phase 7 seal demo |
| 5 | Finite water conserved | `tests/unit/test_water_system.gd` conservation cases |
| 6 | Instability responds to geometry/support | `tests/unit/test_stability_system.gd`, phase 8 smoke (span dig + reinforce + collapse) |
| 7 | Zones react to environmental state | `tests/unit/test_zone_system.gd`, wet-zone invalidation in phase 4/7 flows |
| 8 | ≥1 autonomous emergency response | emergency-haul cases in `test_water_colony_flow.gd` |
| 9 | Save/load restores mid-event world | `tests/phase10_save_smoke.gd` (breach-mid save), fixtures |
| 10 | Seeds pass validator at target rate | `art/qa/reports/phase_5_seed_batch.json` (288/288) |
| 11 | No blocker/critical QA issue | PM judgement after playtests |

Remaining manual checks for the PM: #2 feel, #11, and any regression noticed
during sessions.

## 2. Recruiting & briefing naive players

- 3–6 players who have never seen the game. Mixed backgrounds beat all-gamers.
- Briefing script (read verbatim, no mechanics spoilers):
  > “这是 colony 模拟的早期原型。你指挥几只地下鼠鼠，鼠标左键指派工作、右键取消，
  > 数字键 1–6 切换工具，Esc 打开设置。目标是让鼠鼠的家运转起来，并向下探索。
  > 没有胜利画面——玩 30–45 分钟，按你的直觉来。”
- Do NOT explain: signal fields, span rules, water physics, zone requirements,
  the depth objective's meaning. The tutorial carries onboarding.
- Sit quietly. Do not answer "what does this mean?" beyond "what do you think?".

## 3. Session structure (30–45 min)

Observe silently; note timestamps against the beats (spec §5):

1. **Beat A Space** — first digs, first sleeping area.
2. **Beat B Root clue** — do they notice the root threads? Do they dig toward them?
3. **Beat C Use space** — do they paint zones and watch mice furnish?
4. **Beat D Water clue** — damp patches noticed?
5. **Beat E Breach** — first reaction: pause? seal? reroute? reload?
6. **Beat F Recovery** — do they reshape topology deliberately?
7. **Beat G Instability** — cracks: reinforce, narrow, or ignore?
8. **Beat H Stable end** — can they narrate their burrow's shape?

## 4. Observation sheet (one per player)

```
Player:            Date:            Seed (F4 copies it):
Reached depth:     Collapses seen:  Breaches seen:   Reloads used:

Pauses before digging (spec §7)?            never / 1-2 / often
Uses clues verbally or by digging toward:   root / moisture / neither
Water solutions attempted (list all):
Instability responses attempted (list all):
Tunnel shapes (one wide hall? staircase? branchy?):
After a hazard, first instinct:             adapt / reload / abandon
Post-session: "why does your burrow have this shape?" —
Could narrate:                              yes / partially / no
Mouse autonomy felt:                        helpful / opaque / intrusive
Most frustrating moment:                    (timestamp + what)
Most interesting moment:                    (timestamp + what)
```

## 5. Scoring against the gate

**GO signals** (spec §7): players pause before some digs, use clues to decide,
attempt ≥2 distinct solutions to water/instability across players, shapes
differ between players, hazards lead to adaptation, burrow shapes have
narratives, autonomy feels helpful.

**Red flags** (spec §8): signals ignored by most, digging feels arbitrary,
water always solved by the same seal click, instability is pure annoyance,
colony management dominates attention, UI time exceeds world-watching time,
maps feel empty, hazards leave nothing interesting behind.

**Decision rule**: GO requires the functional checklist fully PASS **and** no
more than one red flag appearing across the majority of players. ITERATE if
signals/hazards/topology read but the loop isn't fun yet — fix design, do not
expand content. NO-GO/PIVOT if the dig decision itself stays uninteresting
after ≥2 iterate rounds.

## 6. Logistics

- Build: run the project (editor ▶ or standalone exe). Settings: Esc menu
  covers language (L also toggles), volumes, reduced particles/shake — set
  these per player before the session.
- Record the screen if players consent; notes are enough.
- After each session, save the observation sheet into
  `art/qa/reports/playtest_<n>.md` (untracked) and aggregate into the Phase 12
  gate report when all sessions are done.
