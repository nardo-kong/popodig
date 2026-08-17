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

if (-not $SkipScreenshot) {
    & $Godot --path $ProjectRoot --log-file .godot/capture.log --script res://tools/qa/capture_screenshot.gd --rendering-driver opengl3
    if ($LASTEXITCODE -ne 0) {
        throw "Screenshot capture failed with exit code $LASTEXITCODE"
    }

    & $Godot --headless --path $ProjectRoot --log-file .godot/screenshot_validation.log --script res://tools/qa/validate_screenshot.gd
    if ($LASTEXITCODE -ne 0) {
        throw "Screenshot validation failed with exit code $LASTEXITCODE"
    }
}

Write-Output "VALIDATION_PASS"
