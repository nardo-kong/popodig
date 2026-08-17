# 21 — Balance & Telemetry Plan

**Status: PROVISIONAL / privacy-conscious**

## 1. Balance philosophy
Tune around decision quality and recovery, not grind length.

Primary questions:
- Do players notice signals?
- Do they make different excavation choices?
- Do hazards produce adaptation rather than frustration?
- Does colony autonomy reduce work or create confusion?
- Does a generated world produce enough meaningful frontiers?

## 2. Local development metrics
Even without external analytics, instrument debug/session summaries:
- total cells excavated;
- cells excavated by material;
- average planned dig batch size;
- time between major discoveries;
- signals encountered before reveal;
- water volume released;
- water contained/redirected;
- flooded storage cells;
- collapse warnings triggered;
- collapses triggered;
- reinforcements placed;
- dig cancellations after warnings;
- zone relocations;
- mouse travel distance/job waiting;
- idle percentage;
- chapter objective time;
- save/reload count if available locally.

## 3. Decision-quality proxies
Useful metrics:
- fraction of major features approached through their strongest signal region;
- fraction of players who dig a mitigation cavity before first water breach after learning the mechanic;
- diversity of routes around a known unstable region;
- percentage of excavated cells that serve no path/zone/feature purpose;
- average frontier signal diversity over time.

These are diagnostic, not player scores.

## 4. Worldgen metrics
Per seed:
- generation time;
- repairs performed;
- feature counts/sizes;
- early food dig-cost distance;
- first water signal distance;
- landmark reachability cost;
- Decision Knot count/spacing;
- traversable/excavatable ratios;
- hard-material barriers;
- failed validation reasons.

## 5. Balance knobs
Centralize:
- dig times/hardness;
- hunger/rest rates;
- food yield;
- population progression;
- water reservoir volume/discharge rate;
- water traversal thresholds;
- stability span rules;
- support material cost;
- signal strength/falloff;
- chapter timing;
- landmark depth ranges.

## 6. Playtest questionnaire
Ask players after slice:
1. What were you usually thinking before choosing where to dig?
2. What did damp/root/crack cues mean to you?
3. Describe the water event in your own words.
4. Did you feel the game punished you unfairly at any point?
5. Did you ever want to directly command a mouse? Why?
6. Which part of your burrow are you most likely to remember? Why does it look that way?
7. Did you feel free to dig where you wanted?
8. Did that freedom ever feel meaningless?

## 7. Telemetry ethics
If external analytics are later added:
- collect only necessary gameplay events;
- document them;
- avoid personal data unless essential and consented;
- respect platform/privacy requirements;
- allow analytics to be disabled where required.
