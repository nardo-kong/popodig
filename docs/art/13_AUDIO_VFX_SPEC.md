# 13 — Audio & VFX Specification

**Status: PROVISIONAL, guided by product pillars**

## 1. Goal
Audio and VFX should make excavation tactile, signals learnable, emergencies legible, and settled colony life cozy without overwhelming the small-scale presentation.

## 2. Audio layers
### Ambient
- muted underground room tone;
- faint surface/weather presence near top;
- localized water trickle;
- occasional structural/root/house sounds by depth.

### Mouse life
- soft footsteps;
- tiny work sounds;
- carry/food rustle;
- sleep/idle chirps used sparingly;
- panic cue during danger.

### Interaction
- tool select;
- designation paint;
- cancel;
- zone assign;
- seal/reinforce.

### Terrain
Material-specific dig impacts for soil/clay/loose/stone/root.

## 3. Signal audio
Audio may reinforce but never exclusively carry critical information.

Examples:
- damp area: faint drip/soft wet ambience;
- hollow cavity: subtle airy/echo cue;
- pipe: periodic hum;
- instability: creak/crumb sound escalating with warning band.

## 4. Discovery stingers
Use short restrained stingers for first reveal of a major feature. Repeated routine interactions use smaller cues.

## 5. Emergency mix
During breach/collapse:
- foreground relevant hazard sound;
- slightly reduce nonessential ambience;
- mouse panic/work sounds remain readable;
- do not use horror-scale alarms that conflict with cozy tone.

## 6. Digging VFX
- dust particles;
- small debris chunks;
- staged cracks;
- restrained screen/world shake for harder materials only;
- no excessive particles that obscure terrain signals.

## 7. Water VFX
- breach burst;
- visible directional transfer/flow accent;
- depth surface ripple;
- small droplets in damp signal area;
- calm stable pool animation.

## 8. Stability VFX
- crumbs;
- falling dust;
- crack propagation within bounded local area;
- collapse debris;
- settling dust afterward.

## 9. Performance
Particle emitters must pool/limit counts. Offscreen audio/VFX should sleep or cull where appropriate.

## 10. Accessibility
- critical states also have visual indicators;
- provide independent volume controls for master/music/SFX/ambience;
- optional reduced screen shake;
- optional reduced particles.
