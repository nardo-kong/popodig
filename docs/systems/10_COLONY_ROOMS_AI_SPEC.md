# 10 — Colony, Rooms & Mouse AI Specification

**Status: LOCKED autonomy model / PROVISIONAL tuning**

## 1. Design goal
Mice should make the burrow feel alive and transform player spatial decisions into visible behavior, without turning the game into individual pawn micromanagement.

## 2. Control contract
Player controls:
- dig designations;
- zones;
- limited priorities;
- environmental actions such as seal/reinforce;
- global pause/speed.

Player does not normally control:
- exact mouse destination;
- manual job assignment per mouse;
- furniture placement;
- detailed schedules;
- skill builds.

## 3. Mouse state
Minimum state:
- unique ID
- world position/current cell
- hunger value
- rest value
- danger state
- current job ID/state
- carried item type/count
- path/repath state
- current animation/state tag

## 4. Needs
### Hunger
Declines over time; mouse seeks accessible food when threshold is reached.

### Rest
Declines with activity/time; mouse seeks valid Sleeping Area.

### Safety
Event-driven rather than a continuous mood bar. Hazards interrupt work and cause escape/repath.

Do not add social, hygiene, entertainment, morale, disease, temperature comfort, etc. in V1 unless separately approved.

## 5. Job types
- Dig
- Haul Food
- Haul Material
- Emergency Haul
- Zone Setup
- Reinforce
- Seal
- Idle/Wander/Social flavor

Flavor actions must never starve critical jobs.

## 6. Job selection
Recommended utility score:
`score = job_priority + urgency + suitability - travel_cost - reservation_penalty`

Keep scoring deterministic/testable where possible.

Needs can interrupt work at thresholds. Danger interrupts immediately.

## 7. Reservation
Jobs/items should support reservations to avoid multiple mice selecting the same single-worker task or hauling the same item.

Dig jobs may optionally allow cooperative work later, but V1 can use one worker per tile.

## 8. Pathfinding
Use grid-based pathfinding over excavated traversable cells.

Path costs may include:
- normal floor/cavity;
- shallow water penalty;
- temporary hazard avoidance;
- blocked/full water;
- rubble;
- closed seal/barrier.

Recompute when topology changes or path becomes invalid, not continuously every frame.

## 9. Traffic
Do not implement full traffic simulation in V1. Topology consequence comes from travel distance and chokepoints.

If crowding becomes visually problematic, use simple local avoidance/occupancy rather than complex agent traffic planning.

## 10. Zones
### Zone representation
A zone is a set of excavated cells with:
- type;
- validity state;
- environmental suitability;
- connectivity;
- occupancy/storage references;
- visual dressing seed.

### Sleeping Area
Requires reachable, unblocked cells. Quality may depend on dry/safe state and distance from active hazards.

### Storage Area
Stores Food and General Material using logical cell capacity. Wet/flooded cells become invalid or trigger emergency haul.

### Food/Forage Area
Interfaces with discovered food feature/processing proxy. Keep production logic minimal.

## 11. Automatic furnishing
When a valid zone is designated, mice perform setup jobs consuming limited General Material if required.

Presentation system then places deterministic decorative props from allowed anchors:
- nests/grass for Sleeping;
- piles/baskets for Storage;
- food scraps/forage visuals for Food.

These props are visual/functional proxies, not individually player-placed furniture objects.

## 12. Zone resizing
Player may repaint/reassign zones. The system should:
- preserve items when possible;
- create haul jobs for invalidated storage;
- re-evaluate suitability;
- update dressing without popping excessively.

## 13. Emergency behavior
### Water breach
- interrupt nearby risky jobs;
- flee from nontraversable rising cells;
- generate emergency haul from threatened Storage.

### Critical collapse warning
- avoid local cells;
- cancel/pause unsafe dig jobs;
- flee if inside risk radius.

## 14. Population growth
**PROVISIONAL:** population increases at chapter/milestone points rather than detailed reproduction simulation.

Growth creates:
- more work capacity;
- more food use;
- more sleeping demand;
- longer traffic chains.

## 15. Mouse personality
Visual micro-personality is encouraged through animation variation, idle timing, names, and cosmetic preferences. It must not require complex simulation in V1.

## 16. Readability
At normal zoom, player should understand:
- who is working;
- who is carrying something;
- who is fleeing;
- where important jobs are happening.

Avoid dense floating text above every mouse.

## 17. Test cases
- hunger interrupts low-priority work and finds food;
- rest seeks valid sleeping zone;
- unreachable job is not repeatedly selected;
- job reservation prevents duplication;
- topology change triggers repath;
- water invalidates route and mouse escapes;
- storage invalidation creates emergency haul;
- zone resize preserves state correctly;
- save/load restores current needs/jobs safely (jobs may be rebuilt if documented).
