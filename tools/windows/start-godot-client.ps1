# Godot 4.7 系で client/ を起動する（Windows 用）
$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$client = Join-Path $root "client"

$candidates = @(
    (Join-Path $root "tools\godot\Godot_v4.7.2-stable_win64.exe"),
    (Join-Path $root "tools\godot\Godot_v4.7-stable_win64.exe"),
    (Join-Path $root "tools\godot\Godot_v4.7-stable_win64_console.exe"),
    (Join-Path $env:USERPROFILE "Documents\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"),
    (Join-Path $env:USERPROFILE "Documents\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"),
    (Join-Path $env:USERPROFILE "Documents\Godot_v4.7.2-stable_win64.exe"),
    (Join-Path $env:USERPROFILE "Documents\Godot_v4.7-stable_win64.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Godot\Godot_v4.7.2-stable_win64.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\Godot\Godot_v4.7-stable_win64.exe")
)

$godot = $null
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) {
        $godot = $c
        break
    }
}

if (-not $godot) {
    $searchRoots = @(
        (Join-Path $root "tools\godot"),
        (Join-Path $env:USERPROFILE "Documents"),
        $env:LOCALAPPDATA
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    $found = Get-ChildItem -Path $searchRoots -Filter "Godot_v4.7*.exe" -Recurse -ErrorAction SilentlyContinue -Depth 4 |
        Where-Object { $_.Name -notmatch "console" } |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if ($found) {
        $godot = $found.FullName
    }
}

if (-not $godot) {
    Write-Error "Godot 4.7 series win64 executable was not found. Put it under tools/godot/ or Documents."
    exit 1
}

Write-Host "Godot: $godot"
& $godot --path $client
