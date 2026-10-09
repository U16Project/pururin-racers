# サーバーの待受を確認してから、Godot クライアントを起動する（Windows 用）。
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path.TrimEnd("\")
$serverDir = Join-Path $root "server"
$serverPython = Join-Path $serverDir ".venv\Scripts\python.exe"
$hostAddress = "127.0.0.1"
$port = 18765
$serverProcess = $null
$keepServer = $false

function Stop-StartedServer {
    if ($null -eq $script:serverProcess) {
        return
    }
    $process = Get-Process -Id $script:serverProcess.Id -ErrorAction SilentlyContinue
    if ($null -ne $process) {
        Write-Host "起動したサーバー (PID $($process.Id)) を停止します。"
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
        Wait-Process -Id $process.Id -Timeout 2 -ErrorAction SilentlyContinue
        if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $serverPython)) {
        throw "server\.venv\Scripts\python.exe が見つかりません。先に仮想環境を用意してください。"
    }

    $serverProcess = Start-Process -FilePath $serverPython -ArgumentList @("main.py") -WorkingDirectory $serverDir -PassThru

    $ready = $false
    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        if ($serverProcess.HasExited) {
            throw "Pythonサーバーが待受開始前に終了しました。"
        }

        $tcp = [Net.Sockets.TcpClient]::new()
        try {
            $connectTask = $tcp.ConnectAsync($hostAddress, $port)
            if ($connectTask.Wait(200) -and $tcp.Connected) {
                $ready = $true
                break
            }
        } catch {
            # 起動直後の接続拒否／タイムアウトは待受未開始の1回分として再試行する。
            $ready = $false
        } finally {
            $tcp.Dispose()
        }
        Start-Sleep -Milliseconds 100
    }

    if (-not $ready) {
        throw "サーバーが $hostAddress`:$port で待受を開始しませんでした。"
    }

    Write-Host "サーバー待受確認OK ($hostAddress`:$port)。Godotを起動します。"
    & (Join-Path $root "tools\windows\start-godot-client.ps1")
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Godotの起動に失敗しました（終了コード $LASTEXITCODE）。"
    }
    $keepServer = $true
} catch {
    Write-Error $_
    exit 1
} finally {
    if (-not $keepServer) {
        Stop-StartedServer
    }
}
