#!/usr/bin/env python3
"""このワークスペースのサーバーと PC 版を止めてから、もう一度起動する。

Linux では build/linux/pururin-racers.x86_64、
Windows では build/windows/pururin-racers.exe を選ぶ。
サーバーは server/.venv の Python で動かす。仮想環境が無ければ作る。
"""

from __future__ import annotations

import json
import os
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path


HOST = "127.0.0.1"
PORT = 18765
ROOT_DIR = Path(__file__).resolve().parent.parent
SERVER_DIR = ROOT_DIR / "server"
VENV_DIR = SERVER_DIR / ".venv"


def fail(message: str) -> None:
    print(f"PC版の再起動に失敗しました: {message}", file=sys.stderr)
    raise SystemExit(1)


def same_path(left: str | Path, right: str | Path) -> bool:
    try:
        return os.path.normcase(os.path.realpath(left)) == os.path.normcase(os.path.realpath(right))
    except OSError:
        return False


def venv_python() -> Path:
    if sys.platform == "win32":
        return VENV_DIR / "Scripts" / "python.exe"
    return VENV_DIR / "bin" / "python"


def client_binary() -> Path:
    if sys.platform == "win32":
        return ROOT_DIR / "build" / "windows" / "pururin-racers.exe"
    if sys.platform.startswith("linux"):
        return ROOT_DIR / "build" / "linux" / "pururin-racers.x86_64"
    fail(f"このスクリプトは Linux と Windows だけに対応しています（今の環境: {sys.platform}）。")
    raise AssertionError


def ensure_server_venv() -> Path:
    python_bin = venv_python()
    if python_bin.is_file():
        print("server/.venv は既に用意されています。")
        return python_bin

    print("server/.venv を作成します。")
    try:
        subprocess.run([sys.executable, "-m", "venv", str(VENV_DIR)], check=True)
        subprocess.run([str(python_bin), "-m", "pip", "install", "-U", "pip"], check=True)
        subprocess.run(
            [str(python_bin), "-m", "pip", "install", "-r", str(SERVER_DIR / "requirements.txt")],
            check=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        fail(f"server/.venv を用意できませんでした（{error}）。")
    print("server/.venv の準備が完了しました。")
    return python_bin


def pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    if sys.platform == "win32":
        return windows_pid_alive(pid)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def windows_pid_alive(pid: int) -> bool:
    import ctypes
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel32.OpenProcess.restype = wintypes.HANDLE
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    handle = kernel32.OpenProcess(0x1000, False, pid)
    if handle:
        kernel32.CloseHandle(handle)
        return True
    return ctypes.get_last_error() == 5


def command_is_server(args: list[str], cwd: str) -> bool:
    """venv の Python で、この server/main.py を実行しているプロセスか。"""
    if len(args) < 2:
        return False
    server_main = SERVER_DIR / "main.py"
    for arg in args[1:]:
        if same_path(arg, server_main):
            return True
        normalized = arg.replace("\\", "/").lower()
        is_main = arg == "main.py" or normalized == "server/main.py" or normalized.endswith("/server/main.py")
        if not is_main:
            continue
        # Windows のプロセス一覧には cwd が無い。実行ファイルがこの venv なら main.py で足りる。
        if not cwd or same_path(cwd, SERVER_DIR):
            return True
    return False


def linux_targets(python_bin: Path, binary: Path) -> list[tuple[int, str]]:
    targets: list[tuple[int, str]] = []
    proc_root = Path("/proc")
    for entry in proc_root.iterdir():
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        if pid == os.getpid():
            continue
        try:
            exe = os.path.realpath(entry / "exe")
            cwd = os.path.realpath(entry / "cwd")
            raw_args = (entry / "cmdline").read_bytes().split(b"\0")
            args = [part.decode("utf-8", "replace") for part in raw_args if part]
        except OSError:
            continue
        if python_bin.is_file() and same_path(exe, python_bin) and command_is_server(args, cwd):
            targets.append((pid, "Pythonサーバー"))
        elif same_path(exe, binary):
            targets.append((pid, "PC版"))
    return targets


def windows_targets(python_bin: Path, binary: Path) -> list[tuple[int, str]]:
    command = (
        "[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); "
        "Get-CimInstance Win32_Process | "
        "Select-Object ProcessId, ExecutablePath, CommandLine | "
        "ConvertTo-Json -Compress -Depth 2"
    )
    completed = subprocess.run(
        ["powershell", "-NoProfile", "-Command", command],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip() or "powershell が失敗しました。"
        fail(f"起動中のプロセスを確認できませんでした（{detail}）。")
    raw = completed.stdout.strip()
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as error:
        fail(f"起動中のプロセス一覧を読めませんでした（{error}）。")
    rows = [parsed] if isinstance(parsed, dict) else list(parsed)
    targets: list[tuple[int, str]] = []
    for row in rows:
        pid = int(row.get("ProcessId") or 0)
        if pid == os.getpid() or pid <= 0:
            continue
        exe = str(row.get("ExecutablePath") or "")
        command_line = str(row.get("CommandLine") or "")
        if python_bin.is_file() and same_path(exe, python_bin) and command_is_server(split_windows_command(command_line), ""):
            targets.append((pid, "Pythonサーバー"))
        elif exe and same_path(exe, binary):
            targets.append((pid, "PC版"))
    return targets


def split_windows_command(command_line: str) -> list[str]:
    if not command_line:
        return []
    try:
        import shlex

        return shlex.split(command_line, posix=False)
    except ValueError:
        return command_line.split()


def running_targets(python_bin: Path, binary: Path) -> list[tuple[int, str]]:
    if sys.platform == "win32":
        return windows_targets(python_bin, binary)
    return linux_targets(python_bin, binary)


def stop_pid(pid: int) -> None:
    if not pid_alive(pid):
        return
    if sys.platform == "win32":
        subprocess.run(["taskkill", "/PID", str(pid)], check=False, capture_output=True)
    else:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            return
    for _ in range(20):
        if not pid_alive(pid):
            return
        time.sleep(0.1)
    if not pid_alive(pid):
        return
    if sys.platform == "win32":
        subprocess.run(["taskkill", "/F", "/PID", str(pid)], check=False, capture_output=True)
    else:
        try:
            os.kill(pid, signal.SIGKILL)
        except OSError:
            pass


def stop_running(python_bin: Path, binary: Path) -> None:
    targets = running_targets(python_bin, binary)
    if not targets:
        print("サーバーとPC版: 停止対象はありませんでした。")
        return
    for pid, kind in targets:
        print(f"{kind} (PID {pid}) を停止します。")
        stop_pid(pid)
    print("サーバーとPC版: 停止処理が完了しました。")


def wait_for_server(server: subprocess.Popen[bytes]) -> None:
    for _ in range(100):
        if server.poll() is not None:
            fail("Pythonサーバーが待受開始前に終了しました。")
        try:
            with socket.create_connection((HOST, PORT), timeout=0.2):
                return
        except OSError:
            time.sleep(0.1)
    stop_pid(server.pid)
    fail(f"サーバーが {HOST}:{PORT} で待受を開始しませんでした。")


def start_server(python_bin: Path) -> subprocess.Popen[bytes]:
    kwargs: dict[str, object] = {
        "cwd": str(SERVER_DIR),
        "stdin": subprocess.DEVNULL,
    }
    if sys.platform == "win32":
        create_new_console = 0x00000010
        kwargs["creationflags"] = create_new_console
    else:
        kwargs["start_new_session"] = True
    try:
        return subprocess.Popen([str(python_bin), "main.py"], **kwargs)  # type: ignore[arg-type]
    except OSError as error:
        fail(f"Pythonサーバーを起動できませんでした（{error}）。")
    raise AssertionError


def start_client(binary: Path, server: subprocess.Popen[bytes]) -> None:
    print(f"サーバー待受確認OK ({HOST}:{PORT})。PC版を起動します。")
    print(f"PC版: {binary}")
    try:
        client = subprocess.Popen([str(binary)], cwd=str(binary.parent))
    except OSError as error:
        stop_pid(server.pid)
        fail(f"PC版を起動できませんでした（{error}）。")
    code = client.wait()
    if code != 0:
        stop_pid(server.pid)
        raise SystemExit(code)


def main() -> None:
    binary = client_binary()
    if not binary.is_file():
        fail(f"PC版が見つかりません（{binary}）。先に書き出してください。")
    if sys.platform.startswith("linux") and not os.access(binary, os.X_OK):
        binary.chmod(binary.stat().st_mode | 0o111)

    python_bin = venv_python()
    print("既存のサーバーとPC版があれば停止します。")
    stop_running(python_bin, binary)
    python_bin = ensure_server_venv()
    print("PythonサーバーとPC版を起動します。")
    server = start_server(python_bin)
    wait_for_server(server)
    start_client(binary, server)


if __name__ == "__main__":
    main()
