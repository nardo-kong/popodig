# 11 — UI/UX Specification

**Status: LOCKED interaction philosophy / PROVISIONAL layouts**

## 1. UX objective
The player should spend most attention on the underground world, not dashboards. UI exists to make spatial conditions legible and actions precise.

## 2. Primary interaction states
- Inspect / default
- Dig
- Cancel
- Zone
- Context Action (seal/reinforce when unlocked)

Avoid a large construction toolbar in V1.

## 3. Desktop controls
**PROVISIONAL:**
- LMB: inspect/select/paint current tool
- RMB/Escape: cancel tool / back
- Middle drag or space+drag: pan
- wheel: zoom
- number/shortcut keys: tool switching
- Space: pause
- 1×/2×/3× speed controls optional

## 4. Touch controls
- one-finger drag on empty/world: pan unless a paint tool is actively engaged with deliberate contact;
- pinch: zoom;
- tap: inspect;
- tap/drag with Dig tool: designate;
- undo/cancel affordance near tool bar;
- optional “paint lock”/hold threshold to reduce accidental digging.

Touch interaction must be validated independently; do not simply map mouse events.

## 5. HUD
Keep permanent HUD small:
- Food
- General Material
- Mouse population
- broad seasonal/progression indicator
- pause/speed
- current tool

Do not permanently display every simulation variable.

## 6. Context Inspector
Selecting a cell/feature shows only known information:
- material name;
- dig difficulty qualitative label;
- visible signals;
- water state if exposed;
- stability warning if applicable;
- zone if excavated;
- feature name once discovered.

Debug numeric values are editor/developer only.

## 7. Dig overlay
When Dig tool active:
- legal cells highlight clearly;
- planned cells use a distinct overlay;
- active/current job differentiates from queued;
- invalid cells show concise reason on inspect/hover;
- planned route remains visible at zoomed-out levels.

## 8. Signal communication
Prefer in-world signals first, optional icon overlay second.

Examples:
- damp soil art + subtle droplet icon in accessibility overlay;
- root thread art + optional root symbol;
- cracks/particles + warning icon at critical stability.

The normal experience should not look like a heatmap.

## 9. Emergency UX
When a major breach/collapse warning occurs:
- brief camera/audio feedback;
- no long modal window;
- local world highlight;
- relevant contextual tool becomes easy to access;
- game may auto-slow briefly only if playtests support it.

The player must retain control of the sandbox.

## 10. Zone UX
Zone painting works only on excavated valid cells.

Display:
- zone tint/pattern while editing;
- room name/icon;
- invalid wet/danger cells;
- auto-dressing preview only if cheap/readable.

Normal view should keep zone tints subtle or hidden unless requested.

## 11. Tutorial philosophy
Tutorial is contextual and action-first.

Do:
- one sentence prompt;
- highlight relevant world area;
- let the player perform the real action;
- explain signals immediately before/after first relevant encounter.

Do not:
- show multi-page manuals;
- explain future systems before they matter;
- force fixed A/B route decisions.

## 12. First 10 minutes UX script
1. Show cramped burrow and 3 mice.
2. Prompt: “这里有点挤，挖一点空间吧。”
3. Player freely designates nearby soil.
4. Show mice digging; no extra menu.
5. Introduce Sleeping Area after space exists.
6. Food need becomes visible.
7. Fine root cue appears along a frontier.
8. Inspector teaches “迹象” concept without revealing exact root shape.
9. Player decides whether/how to approach.

## 13. Camera
Requirements:
- smooth pan/zoom;
- fit-to-active-burrow/home shortcut;
- focus-on-event button/notification;
- no forced camera lock during normal events;
- maintain mouse/world readability across supported aspect ratios.

## 14. Notifications
Use a small event queue for:
- discovery revealed;
- zone invalidated;
- food critically low;
- mouse trapped/danger;
- chapter milestone.

Avoid notification spam from routine hauling/dig completion.

## 15. Accessibility
Plan for:
- UI scale;
- high-contrast overlays;
- signal icons independent of color;
- reduced motion/particles;
- readable fonts;
- remappable keyboard controls where feasible;
- touch target minimum sizing;
- pause-friendly play.

## 16. Debug panel
Editor/debug builds should expose collapsible panels for:
- seed/worldgen regenerate;
- signal overlays;
- water units;
- stability;
- pathing;
- jobs;
- time controls;
- spawn/reveal test feature;
- screenshot capture.

Debug UI must not ship visible in release mode.
