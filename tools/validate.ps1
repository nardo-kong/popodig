param(
    [string]$Godot = $env:DIGDOWN_GODOT_BIN,
    [switch]$SkipScreenshot
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ([string]::IsNullOrWhiteSpace($Godot)) {
    foreach ($CommandName in @("godot4", "godot")) {
        $Command = Get-Command $CommandName -ErrorAction SilentlyContinue
        if ($null -ne $Command) {
            $Godot = $Command.Source
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Godot)) {
    $DownloadCandidate = Join-Path $env:USERPROFILE "Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
    if (Test-Path -LiteralPath $DownloadCandidate -PathType Leaf) {
        $Godot = $DownloadCandidate
    }
}

if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot 4.7 executable not found. Pass -Godot or set DIGDOWN_GODOT_BIN."
}

& $Godot --headless --path $ProjectRoot --log-file .godot/import.log --editor --quit
if ($LASTEXITCODE -ne 0) {
    throw "Godot import/parse failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/main_scene.log --quit-after 3
if ($LASTEXITCODE -ne 0) {
    throw "Main scene smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/tests.log --script res://tests/test_runner.gd
if ($LASTEXITCODE -ne 0) {
    throw "Automated tests failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/profile_development.log --script res://tests/profile_smoke.gd -- --expect-profile=development
if ($LASTEXITCODE -ne 0) {
    throw "Development profile smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/profile_release.log --script res://tests/profile_smoke.gd -- --profile=release --expect-profile=release
if ($LASTEXITCODE -ne 0) {
    throw "Release profile smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase1_scene_development.log --script res://tests/phase1_scene_smoke.gd -- --expect-debug=true
if ($LASTEXITCODE -ne 0) {
    throw "Phase 1 development scene smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase1_scene_release.log --script res://tests/phase1_scene_smoke.gd -- --profile=release --expect-debug=false
if ($LASTEXITCODE -ne 0) {
    throw "Phase 1 release-clean scene smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase1_large_render.log --script res://tests/phase1_large_render_smoke.gd
if ($LASTEXITCODE -ne 0) {
    throw "Phase 1 large-render/local-redraw smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase2_playable_development.log --script res://tests/phase2_playable_smoke.gd -- --expect-debug=true
if ($LASTEXITCODE -ne 0) {
    throw "Phase 2 playable digging smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase2_playable_release.log --script res://tests/phase2_playable_smoke.gd -- --profile=release --expect-debug=false --qa-phase2-demo
if ($LASTEXITCODE -ne 0) {
    throw "Phase 2 release playable digging smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase3_colony_development.log --script res://tests/phase3_colony_smoke.gd -- --expect-debug=true --qa-phase3-demo
if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 development colony smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase3_colony_release.log --script res://tests/phase3_colony_smoke.gd -- --profile=release --expect-debug=false --qa-phase3-demo
if ($LASTEXITCODE -ne 0) {
    throw "Phase 3 release colony smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase4_zones_development.log --script res://tests/phase4_zones_smoke.gd -- --profile=development --expect-debug=true
if ($LASTEXITCODE -ne 0) {
    throw "Phase 4 development zones smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase4_zones_release.log --script res://tests/phase4_zones_smoke.gd -- --profile=release --expect-debug=false --qa-phase4-demo
if ($LASTEXITCODE -ne 0) {
    throw "Phase 4 release zones smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase4_zone_churn_benchmark.log --script res://tools/qa/benchmark_phase4_zone_churn.gd
if ($LASTEXITCODE -ne 0) {
    throw "Phase 4 large-zone churn benchmark failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase5_worldgen_development.log --script res://tests/phase5_worldgen_smoke.gd -- --profile=development --expect-debug=true --qa-phase5-overlay=features
if ($LASTEXITCODE -ne 0) {
    throw "Phase 5 development structured-worldgen smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase5_worldgen_release.log --script res://tests/phase5_worldgen_smoke.gd -- --profile=release --expect-debug=false --qa-phase5-overlay=features
if ($LASTEXITCODE -ne 0) {
    throw "Phase 5 release-clean structured-worldgen smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase5_seed_batch.log --script res://tools/qa/batch_phase5_worldgen.gd
if ($LASTEXITCODE -ne 0) {
    throw "Phase 5 structured-worldgen seed batch failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase5_fresh_replay.log --script res://tools/qa/verify_phase5_batch_replay.gd
if ($LASTEXITCODE -ne 0) {
    throw "Phase 5 fresh-process seed replay failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase6_root_development.log --script res://tests/phase6_root_smoke.gd -- --profile=development --expect-debug=true --qa-phase6-overlay=signal_bands
if ($LASTEXITCODE -ne 0) {
    throw "Phase 6 development Root lifecycle smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase6_root_release.log --script res://tests/phase6_root_smoke.gd -- --profile=release --expect-debug=false --qa-phase6-overlay=signal_bands
if ($LASTEXITCODE -ne 0) {
    throw "Phase 6 release-clean Root lifecycle smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase7_water_development.log --script res://tests/phase7_water_smoke.gd -- --profile=development --expect-debug=true --qa-phase7-overlay=water
if ($LASTEXITCODE -ne 0) {
    throw "Phase 7 development water lifecycle smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase7_water_release.log --script res://tests/phase7_water_smoke.gd -- --profile=release --expect-debug=false --qa-phase7-overlay=water
if ($LASTEXITCODE -ne 0) {
    throw "Phase 7 release-clean water lifecycle smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase8_stability_development.log --script res://tests/phase8_stability_smoke.gd -- --profile=development --expect-debug=true
if ($LASTEXITCODE -ne 0) {
    throw "Phase 8 development stability lifecycle smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase8_stability_release.log --script res://tests/phase8_stability_smoke.gd -- --profile=release --expect-debug=false
if ($LASTEXITCODE -ne 0) {
    throw "Phase 8 release-clean stability lifecycle smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase10_save_smoke.log --script res://tests/phase10_save_smoke.gd -- --profile=development
if ($LASTEXITCODE -ne 0) {
    throw "Phase 10 save/load smoke failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase10_fixture_new_game.log --script res://tools/qa/export_phase10_fixtures.gd -- --profile=development --fixture=new_game
if ($LASTEXITCODE -ne 0) {
    throw "Phase 10 new_game fixture export failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase10_fixture_zones_mice.log --script res://tools/qa/export_phase10_fixtures.gd -- --profile=development --fixture=zones_mice --qa-phase4-demo
if ($LASTEXITCODE -ne 0) {
    throw "Phase 10 zones_mice fixture export failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase10_fixture_root_reveal.log --script res://tools/qa/export_phase10_fixtures.gd -- --profile=development --fixture=root_reveal --qa-phase6-demo=reveal
if ($LASTEXITCODE -ne 0) {
    throw "Phase 10 root_reveal fixture export failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase10_fixture_water_breach.log --script res://tools/qa/export_phase10_fixtures.gd -- --profile=development --fixture=water_breach --qa-phase7-demo=breach
if ($LASTEXITCODE -ne 0) {
    throw "Phase 10 water_breach fixture export failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase10_fixture_post_collapse.log --script res://tools/qa/export_phase10_fixtures.gd -- --profile=development --fixture=post_collapse --qa-phase8-demo=collapse
if ($LASTEXITCODE -ne 0) {
    throw "Phase 10 post_collapse fixture export failed with exit code $LASTEXITCODE"
}

& $Godot --headless --path $ProjectRoot --log-file .godot/phase7_water_benchmark.log --script res://tools/qa/benchmark_phase7_water.gd
if ($LASTEXITCODE -ne 0) {
    throw "Phase 7 bounded water benchmark failed with exit code $LASTEXITCODE"
}

if (-not $SkipScreenshot) {
    & $Godot --path $ProjectRoot --disable-vsync --log-file .godot/phase1_benchmark.log --script res://tools/qa/benchmark_runtime.gd --rendering-driver opengl3
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 1 runtime benchmark failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --disable-vsync --log-file .godot/phase2_gameplay_benchmark.log --script res://tools/qa/benchmark_phase2_gameplay.gd --rendering-driver opengl3 -- --qa-phase2-demo
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 2 gameplay benchmark failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --disable-vsync --log-file .godot/phase3_colony_benchmark.log --script res://tools/qa/benchmark_phase3_colony.gd --rendering-driver opengl3 -- --qa-phase3-demo
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 3 colony benchmark failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --disable-vsync --log-file .godot/phase4_zones_benchmark.log --script res://tools/qa/benchmark_phase4_zones.gd --rendering-driver opengl3 -- --qa-phase4-demo
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4 zones benchmark failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --disable-vsync --log-file .godot/phase6_signal_benchmark.log --script res://tools/qa/benchmark_phase6_signals.gd --rendering-driver opengl3 -- --qa-phase6-demo=clue
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 6 signal runtime benchmark failed with exit code $LASTEXITCODE"
    }
}

if (-not $SkipScreenshot) {
    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation.log --script res://tools/qa/validate_screenshot.gd
    if ($LASTEXITCODE -ne 0) {
        throw "Screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_1920.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_2_digging_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "1920x1080 screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_release.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_2_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Release-clean screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase3.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_3_colony.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 3 screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase3_1920.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_3_colony_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 3 1920x1080 screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase3_release.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_3_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 3 release-clean screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase4.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --qa-phase4-demo --wait-for-zones --output=res://art/qa/screenshots/phase_4_zones.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4 screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase4.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_4_zones.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4 screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase4_1920.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --qa-phase4-demo --wait-for-zones --output=res://art/qa/screenshots/phase_4_zones_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4 1920x1080 screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase4_1920.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_4_zones_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4 1920x1080 screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase4_wet_storage.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --qa-phase4-demo --wait-for-wet-storage --output=res://art/qa/screenshots/phase_4_wet_storage.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4 wet-Storage screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase4_wet_storage.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_4_wet_storage.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4 wet-Storage screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase4_release.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=release --qa-phase4-demo --output=res://art/qa/screenshots/phase_4_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4 release-clean screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase4_release.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_4_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 4 release-clean screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase5_features.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase5-overlay=features --output=res://art/qa/screenshots/phase_5_worldgen_features.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 5 feature-overlay screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase5_features.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_5_worldgen_features.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 5 feature-overlay screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase5_strata.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase5-overlay=strata --output=res://art/qa/screenshots/phase_5_worldgen_strata_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 5 strata-overlay 1920x1080 screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase5_strata.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_5_worldgen_strata_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 5 strata-overlay 1920x1080 screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase5_release.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=release --qa-phase5-overlay=features --output=res://art/qa/screenshots/phase_5_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 5 release-clean screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase5_release.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_5_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 5 release-clean screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase6_clues.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase6-demo=clue --output=res://art/qa/screenshots/phase_6_root_clues.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 6 normal Root-clue screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase6_clues.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_6_root_clues.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 6 normal Root-clue screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase6_raw.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase6-demo=clue --qa-phase6-overlay=root_raw --output=res://art/qa/screenshots/phase_6_root_signal_raw_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 6 raw-signal screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase6_raw.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_6_root_signal_raw_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 6 raw-signal screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase6_stable.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase6-demo=reveal --output=res://art/qa/screenshots/phase_6_root_stable.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 6 revealed-Root screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase6_stable.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_6_root_stable.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 6 revealed-Root screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase6_release.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=release --qa-phase6-overlay=root_raw --output=res://art/qa/screenshots/phase_6_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 6 release-clean screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase6_release.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_6_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 6 release-clean screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase7_clues.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase7-demo=clue --output=res://art/qa/screenshots/phase_7_moisture_clues.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 normal moisture-clue screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase7_clues.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_7_moisture_clues.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 normal moisture-clue screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase7_breach.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase7-demo=breach --output=res://art/qa/screenshots/phase_7_reservoir_breach.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 reservoir-breach screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase7_breach.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_7_reservoir_breach.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 reservoir-breach screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase7_water_debug.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase7-demo=breach --qa-phase7-overlay=water --output=res://art/qa/screenshots/phase_7_water_flow_debug_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 water-flow debug screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase7_water_debug.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_7_water_flow_debug_1920x1080.png --size=1920x1080
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 water-flow debug screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase7_seal.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase7-demo=seal --output=res://art/qa/screenshots/phase_7_seal_recovery.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 seal-recovery screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase7_seal.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_7_seal_recovery.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 seal-recovery screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase7_release.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=release --qa-phase7-demo=breach --qa-phase7-overlay=water --output=res://art/qa/screenshots/phase_7_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 release-clean screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase7_release.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_7_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 7 release-clean screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase8_warnings.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase8-demo=warn --output=res://art/qa/screenshots/phase_8_stability_warnings.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 8 stability-warnings screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase8_warnings.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_8_stability_warnings.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 8 stability-warnings screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase8_reinforced.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase8-demo=reinforce --output=res://art/qa/screenshots/phase_8_reinforced_support.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 8 reinforced-support screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase8_reinforced.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_8_reinforced_support.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 8 reinforced-support screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase8_collapse.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase8-demo=collapse --output=res://art/qa/screenshots/phase_8_bounded_collapse.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 8 bounded-collapse screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase8_collapse.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_8_bounded_collapse.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 8 bounded-collapse screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase8_release.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=release --qa-phase8-demo=warn --output=res://art/qa/screenshots/phase_8_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 8 release-clean screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase8_release.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_8_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 8 release-clean screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/phase9_ux_development.log --script res://tests/phase9_ux_smoke.gd -- --profile=development --expect-debug=true
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 9 development UX smoke failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/phase9_ux_release.log --script res://tests/phase9_ux_smoke.gd -- --profile=release --expect-debug=false
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 9 release-clean UX smoke failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase9_hud.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase2-demo --output=res://art/qa/screenshots/phase_9_hud_tutorial.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 9 HUD/tutorial screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase9_hud.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_9_hud_tutorial.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 9 HUD/tutorial screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase9_discovery.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase6-demo=reveal --output=res://art/qa/screenshots/phase_9_root_discovery.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 9 discovery notification screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase9_discovery.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_9_root_discovery.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 9 discovery notification screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase9_release.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=release --output=res://art/qa/screenshots/phase_9_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 9 release-clean screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase9_release.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_9_release_clean.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 9 release-clean screenshot validation failed with exit code $LASTEXITCODE"
    }

    # Phase 11 art pass (docs/art/12 §16): close-up terrain transitions on the
    # dig-demo path, mouse state animation, animated water close-up, zone dressing.
    & $Godot --path $ProjectRoot --log-file .godot/capture_phase11_transitions.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase2-demo --qa-zoom=2.2 --qa-focus=start --output=res://art/qa/screenshots/phase_11_terrain_transitions.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 11 terrain-transitions screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase11_transitions.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_11_terrain_transitions.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 11 terrain-transitions screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase11_mouse_states.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase3-demo --wait-for-carry --qa-zoom=2.0 --qa-focus=start --output=res://art/qa/screenshots/phase_11_mouse_states.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 11 mouse-state screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase11_mouse_states.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_11_mouse_states.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 11 mouse-state screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase11_water_closeup.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase7-demo=breach --qa-zoom=2.0 --output=res://art/qa/screenshots/phase_11_water_closeup.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 11 water close-up screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase11_water_closeup.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_11_water_closeup.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 11 water close-up screenshot validation failed with exit code $LASTEXITCODE"
    }

    & $Godot --path $ProjectRoot --log-file .godot/capture_phase11_zone_dressing.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-phase4-demo --wait-for-zones --qa-zoom=2.2 --qa-focus=start --output=res://art/qa/screenshots/phase_11_zone_dressing.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 11 zone-dressing screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase11_zone_dressing.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_11_zone_dressing.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 11 zone-dressing screenshot validation failed with exit code $LASTEXITCODE"
    }

    # Phase 16: fog-of-war darkness evidence (undug ground reads dark).
    & $Godot --path $ProjectRoot --log-file .godot/capture_phase16_fog.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --output=res://art/qa/screenshots/phase_16_fog_of_war.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 16 fog screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase16_fog.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_16_fog_of_war.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 16 fog screenshot validation failed with exit code $LASTEXITCODE"
    }

    # Phase 12: player settings overlay (quick-load confirm, volumes, a11y).
    & $Godot --path $ProjectRoot --log-file .godot/capture_phase12_settings.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3 -- --profile=development --qa-open-settings --output=res://art/qa/screenshots/phase_12_settings_menu.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 12 settings-menu screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation_phase12_settings.log --script res://tools/qa/validate_screenshot.gd -- --input=res://art/qa/screenshots/phase_12_settings_menu.png
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 12 settings-menu screenshot validation failed with exit code $LASTEXITCODE"
    }
}

$ValidationLogs = @(
    "import.log",
    "main_scene.log",
    "tests.log",
    "profile_development.log",
    "profile_release.log",
    "phase1_scene_development.log",
    "phase1_scene_release.log",
    "phase1_large_render.log",
    "phase2_playable_development.log",
    "phase2_playable_release.log",
    "phase3_colony_development.log",
    "phase3_colony_release.log",
    "phase4_zones_development.log",
    "phase4_zones_release.log",
    "phase4_zone_churn_benchmark.log",
    "phase5_worldgen_development.log",
    "phase5_worldgen_release.log",
    "phase5_seed_batch.log",
    "phase5_fresh_replay.log",
    "phase6_root_development.log",
    "phase6_root_release.log",
    "phase7_water_development.log",
    "phase7_water_release.log",
    "phase7_water_benchmark.log",
    "phase8_stability_development.log",
    "phase8_stability_release.log",
    "phase9_ux_development.log",
    "phase9_ux_release.log",
    "phase10_save_smoke.log",
    "phase10_fixture_new_game.log",
    "phase10_fixture_zones_mice.log",
    "phase10_fixture_root_reveal.log",
    "phase10_fixture_water_breach.log",
    "phase10_fixture_post_collapse.log"
)
if (-not $SkipScreenshot) {
    $ValidationLogs += @(
        "phase1_benchmark.log",
        "phase2_gameplay_benchmark.log",
        "phase3_colony_benchmark.log",
        "phase4_zones_benchmark.log",
        "phase6_signal_benchmark.log",
        "screenshot_validation.log",
        "screenshot_validation_1920.log",
        "screenshot_validation_release.log",
        "screenshot_validation_phase3.log",
        "screenshot_validation_phase3_1920.log",
        "screenshot_validation_phase3_release.log",
        "capture_phase4.log",
        "screenshot_validation_phase4.log",
        "capture_phase4_1920.log",
        "screenshot_validation_phase4_1920.log",
        "capture_phase4_wet_storage.log",
        "screenshot_validation_phase4_wet_storage.log",
        "capture_phase4_release.log",
        "screenshot_validation_phase4_release.log",
        "capture_phase5_features.log",
        "screenshot_validation_phase5_features.log",
        "capture_phase5_strata.log",
        "screenshot_validation_phase5_strata.log",
        "capture_phase5_release.log",
        "screenshot_validation_phase5_release.log",
        "capture_phase6_clues.log",
        "screenshot_validation_phase6_clues.log",
        "capture_phase6_raw.log",
        "screenshot_validation_phase6_raw.log",
        "capture_phase6_stable.log",
        "screenshot_validation_phase6_stable.log",
        "capture_phase6_release.log",
        "screenshot_validation_phase6_release.log",
        "capture_phase7_clues.log",
        "screenshot_validation_phase7_clues.log",
        "capture_phase7_breach.log",
        "screenshot_validation_phase7_breach.log",
        "capture_phase7_water_debug.log",
        "screenshot_validation_phase7_water_debug.log",
        "capture_phase7_seal.log",
        "screenshot_validation_phase7_seal.log",
        "capture_phase7_release.log",
        "screenshot_validation_phase7_release.log",
        "capture_phase8_warnings.log",
        "screenshot_validation_phase8_warnings.log",
        "capture_phase8_reinforced.log",
        "screenshot_validation_phase8_reinforced.log",
        "capture_phase8_collapse.log",
        "screenshot_validation_phase8_collapse.log",
        "capture_phase8_release.log",
        "screenshot_validation_phase8_release.log",
        "capture_phase9_hud.log",
        "screenshot_validation_phase9_hud.log",
        "capture_phase9_discovery.log",
        "screenshot_validation_phase9_discovery.log",
        "capture_phase9_release.log",
        "screenshot_validation_phase9_release.log",
        "capture_phase11_transitions.log",
        "screenshot_validation_phase11_transitions.log",
        "capture_phase11_mouse_states.log",
        "screenshot_validation_phase11_mouse_states.log",
        "capture_phase11_water_closeup.log",
        "screenshot_validation_phase11_water_closeup.log",
        "capture_phase11_zone_dressing.log",
        "screenshot_validation_phase11_zone_dressing.log",
        "capture_phase16_fog.log",
        "screenshot_validation_phase16_fog.log",
        "capture_phase12_settings.log",
        "screenshot_validation_phase12_settings.log"
    )
}

foreach ($LogName in $ValidationLogs) {
    $LogPath = Join-Path $ProjectRoot ".godot\$LogName"
    if (-not (Test-Path -LiteralPath $LogPath)) {
        continue
    }
    # The corruption-recovery unit test deliberately feeds a truncated save
    # to SaveService.load_game, so Godot prints one expected engine-level
    # JSON parse error; everything else must stay clean. SCRIPT ERROR lines
    # are matched too — runtime script errors must fail the gate.
    $UnexpectedErrors = Select-String -LiteralPath $LogPath -Pattern '^(ERROR|SCRIPT ERROR):' |
        Where-Object { $_.Line -notmatch '^ERROR: Parse JSON failed\. Error at line 0: Unterminated string' }
    if ($UnexpectedErrors) {
        throw "Godot reported an error in validation log: $LogPath"
    }
}

Write-Output "VALIDATION_PASS"
