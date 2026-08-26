# server/.venv を用意する（Windows 用）
$ErrorActionPreference = "Stop"

$server = Resolve-Path (Join-Path $PSScriptRoot "..\..\server")
Set-Location $server

$python = Join-Path $server ".venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $python)) {
    py -3 -m venv .venv
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & .\.venv\Scripts\python.exe -m pip install -U pip
    & .\.venv\Scripts\pip.exe install -r requirements.txt
}

Write-Host "server/.venv ready"
