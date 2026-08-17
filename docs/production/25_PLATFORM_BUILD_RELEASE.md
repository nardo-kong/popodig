# 25 — Platform, Build & Release Specification

**Status: PROVISIONAL platform scope / LOCKED build hygiene**

## 1. Development platform baseline
Primary development and validation should target desktop first because free camera, debug overlays, seed tooling, and simulation inspection are easiest there.

Godot version is locked to 4.7 stable for the project baseline unless a controlled upgrade is approved.

## 2. Target platform strategy
### Phase A
Desktop keyboard/mouse build is mandatory for Vertical Slice.

### Phase B
Touch/mobile support may be included in the Vertical Slice if explicitly prioritized; otherwise it becomes the next platform pass after core-loop validation.

### Future
Additional desktop/mobile storefront packaging depends on product decision and performance QA.

## 3. Input abstraction
Gameplay commands must be input-device agnostic. Mouse, touch, controller (if later supported) map into the same application commands.

Never put gameplay logic directly inside raw input callbacks.

## 4. Build profiles
Maintain at minimum:
- `Development` — debug UI, verbose diagnostics, seed tools.
- `QA` — representative performance plus test/debug shortcuts as needed.
- `Release` — no visible debug UI, no developer cheats, reduced logging.

## 5. Release configuration checks
Before any candidate build:
- correct app name/version;
- debug features disabled;
- logs appropriate;
- save path verified;
- clean first-launch behavior;
- supported resolution/UI scale verified;
- all required assets included;
- unused large prototype assets removed;
- legal/license manifest complete.

## 6. Versioning
Recommended semantic-ish version flow:
- `0.1.x` engineering foundation
- `0.2.x` Vertical Slice systems
- `0.3.x` Vertical Slice polished/playtest
- `0.4–0.8` chapter/content development
- `0.9.x` beta/RC hardening
- `1.0.0` initial full release

Git tags should correspond to approved major milestones, not every task.

## 7. Crash/log collection
Development builds should write useful logs including seed and save schema/worldgen version when an error occurs.

Do not expose sensitive local paths or unnecessary personal information in release telemetry/logs.

## 8. Resolution policy
World rendering must support variable viewport sizes without changing logical simulation.

UI must use anchors/containers rather than fixed absolute placement where practical.

## 9. Pause/background behavior
On platforms that can suspend:
- save at safe transitions where appropriate;
- pause simulation when app loses focus if needed;
- avoid large time skips unless intentionally designed.

## 10. Release gate
A build cannot be called Release Candidate until `17_TEST_QA_PLAN.md` release gates and asset-license checks pass.
