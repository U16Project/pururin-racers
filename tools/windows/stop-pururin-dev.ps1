# このワークスペースで起動した Pururin 開発用プロセスだけを停止する（Windows 用）。

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path.TrimEnd("\")
$serverPython = Join-Path $root "server\.venv\Scripts\python.exe"
$clientPath = (Resolve-Path (Join-Path $root "client")).Path.TrimEnd("\").ToLowerInvariant()

function Normalize-PathString([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        return ""
    }
    try {
        return [IO.Path]::GetFullPath($path).TrimEnd("\").ToLowerInvariant()
    } catch {
        return ""
    }
}

$pythonPath = Normalize-PathString $serverPython
$targets = @()

foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
    $commandLine = [string]$process.CommandLine
    $executablePath = Normalize-PathString ([string]$process.ExecutablePath)
    $executableName = [IO.Path]::GetFileName($executablePath)

    $isServer = $false
    if ($executablePath -eq $pythonPath) {
        # タスクの起動形（server を cwd にして main.py）と、絶対パス指定の両方を許可する。
        $isServer = ($commandLine -match '(?i)(^|[\s"])main\.py($|[\s"])') -or
            ($commandLine -match '(?i)[\\/]server[\\/]main\.py($|[\s"])')
    }

    $normalizedCommandLine = $commandLine.Replace("/", "\").ToLowerInvariant()
    $isGodot = ($executableName -match '(?i)^godot') -and
        ($normalizedCommandLine.Contains($clientPath)) -and
        ($normalizedCommandLine -match '(?i)--path')

    if ($isServer -or $isGodot) {
        $kind = if ($isServer) { "Pythonサーバー" } else { "Godotクライアント" }
        $targets += [PSCustomObject]@{ Id = [int]$process.ProcessId; Kind = $kind }
    }
}

if ($targets.Count -eq 0) {
    Write-Host "Pururin開発プロセス: 停止対象はありませんでした。"
    exit 0
}

foreach ($target in $targets) {
    Write-Host "$($target.Kind) (PID $($target.Id)) を停止します。"
    Stop-Process -Id $target.Id -ErrorAction SilentlyContinue
}

for ($attempt = 0; $attempt -lt 20; $attempt++) {
    $remaining = @($targets | Where-Object { Get-Process -Id $_.Id -ErrorAction SilentlyContinue })
    if ($remaining.Count -eq 0) {
        break
    }
    Start-Sleep -Milliseconds 100
}

foreach ($target in $targets) {
    if (Get-Process -Id $target.Id -ErrorAction SilentlyContinue) {
        Write-Host "$($target.Kind) (PID $($target.Id)) が残ったため強制終了します。"
        Stop-Process -Id $target.Id -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Pururin開発プロセス: 停止処理が完了しました。"
