import os
import shutil
import subprocess
import sys
import threading
import urllib.request
import webbrowser
import urllib.parse
import time
import logging
from logging.handlers import RotatingFileHandler
import ctypes
from ctypes import wintypes
from pathlib import Path
import tkinter as tk
from tkinter import messagebox

APP_NAME = "PANDA ROYALE"
DISCORD_APPLICATION_ID = "1562710544010584155"  # Public game application ID for Rich Presence
GAME_EXE = "PandaRoyale.exe"
GAME_DOWNLOAD_URL = "https://github.com/PandaManDev/Panda-Royale/releases/latest/download/PandaRoyale.exe"
RELEASES_URL = "https://github.com/PandaManDev/Panda-Royale/releases/latest"
BG = "#090b14"
PANEL = "#111626"
PURPLE = "#8b5cf6"
CYAN = "#42e8ff"
TEXT = "#f4f5ff"
MUTED = "#9aa4bd"


BACKGROUND_SERVICE_NAME = "Panda Royale Background Service"


def _process_is_running(pid: int) -> bool:
    if sys.platform != "win32":
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    STILL_ACTIVE = 259
    kernel32 = ctypes.windll.kernel32
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not handle:
        # Access denied means the process exists; other errors usually mean it exited.
        return ctypes.get_last_error() == 5
    try:
        exit_code = wintypes.DWORD()
        if not kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code)):
            return False
        return exit_code.value == STILL_ACTIVE
    finally:
        kernel32.CloseHandle(handle)


def run_background_service(game_pid: int) -> int:
    """Quiet companion process: keep Discord Rich Presence alive and watch the game process."""
    client = None
    app_id = os.environ.get("PANDA_ROYALE_DISCORD_APP_ID", "").strip() or DISCORD_APPLICATION_ID
    next_rpc_attempt = 0.0
    try:
        while _process_is_running(game_pid):
            now = time.monotonic()
            if client is None and now >= next_rpc_attempt:
                try:
                    from pypresence import Presence
                    client = Presence(app_id)
                    client.connect()
                    client.update(details="Playing Panda Royale", state="In the arena", start=int(time.time()), large_text="Panda Royale", small_text="Early Access")\n                    logger.info("Discord Rich Presence connected")
                except Exception:
                    if client is not None:
                        try:
                            client.close()
                        except Exception:
                            pass
                    client = None
                    next_rpc_attempt = now + 10.0
            time.sleep(2.0)
    finally:
        if client is not None:
            try:
                client.clear()
                client.close()
            except Exception:
                pass
    return 0


def start_background_service(game_pid: int) -> None:
    """Spawn a detached companion that outlives the launcher window, but exits with the game."""
    if getattr(sys, "frozen", False):
        command = [sys.executable, "--background-service", str(game_pid)]
    else:
        command = [sys.executable, str(Path(__file__).resolve()), "--background-service", str(game_pid)]
    flags = 0
    startupinfo = None
    if sys.platform == "win32":
        flags = getattr(subprocess, "DETACHED_PROCESS", 0x00000008) | getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 0
    try:
        subprocess.Popen(command, cwd=str(launcher_folder()), stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         creationflags=flags, startupinfo=startupinfo, close_fds=True)
    except OSError:
        # The game must still launch even if the optional helper cannot start.
        pass


def launcher_folder() -> Path:
    return Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent


def install_folder() -> Path:
    base = os.environ.get("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
    return Path(base) / "PandaRoyale"


def configure_logging(log_name: str = "launcher.log") -> logging.Logger:
    """Write rotating diagnostics to the user's local AppData install folder."""
    logger = logging.getLogger("panda_royale")
    logger.setLevel(logging.INFO)
    if not logger.handlers:
        try:
            log_dir = install_folder() / "logs"
            log_dir.mkdir(parents=True, exist_ok=True)
            handler = RotatingFileHandler(
                log_dir / log_name, maxBytes=1_000_000, backupCount=3, encoding="utf-8"
            )
            handler.setFormatter(logging.Formatter(
                "%(asctime)s | %(levelname)s | %(process)d | %(message)s",
                datefmt="%Y-%m-%d %H:%M:%S",
            ))
            logger.addHandler(handler)
        except OSError:
            # Logging must never prevent the launcher or game from starting.
            logger.addHandler(logging.NullHandler())
    return logger


MIN_RAM_GB = 4
MIN_CPU_CORES = 2
MIN_FREE_DISK_GB = 1


def get_system_specs() -> dict:
    """Read basic Windows hardware data using built-in APIs."""
    specs = {
        "os_ok": sys.platform == "win32",
        "os_name": "Windows",
        "cpu_cores": os.cpu_count() or 1,
        "ram_gb": 0.0,
        "free_disk_gb": 0.0,
        "install_path": str(install_folder()),
        "gpu_note": "Graphics/OpenGL support cannot be reliably confirmed by this lightweight check.",
    }
    if sys.platform == "win32":
        try:
            version = sys.getwindowsversion()
            specs["os_name"] = f"Windows {version.major}.{version.minor} (build {version.build})"
            specs["os_ok"] = version.major >= 10
        except Exception:
            specs["os_ok"] = False
        try:
            class MEMORYSTATUSEX(ctypes.Structure):
                _fields_ = [
                    ("dwLength", wintypes.DWORD),
                    ("dwMemoryLoad", wintypes.DWORD),
                    ("ullTotalPhys", ctypes.c_ulonglong),
                    ("ullAvailPhys", ctypes.c_ulonglong),
                    ("ullTotalPageFile", ctypes.c_ulonglong),
                    ("ullAvailPageFile", ctypes.c_ulonglong),
                    ("ullTotalVirtual", ctypes.c_ulonglong),
                    ("ullAvailVirtual", ctypes.c_ulonglong),
                    ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
                ]
            status = MEMORYSTATUSEX()
            status.dwLength = ctypes.sizeof(status)
            if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
                specs["ram_gb"] = status.ullTotalPhys / (1024 ** 3)
        except Exception:
            pass
    try:
        path = install_folder()
        path.mkdir(parents=True, exist_ok=True)
        specs["free_disk_gb"] = shutil.disk_usage(path).free / (1024 ** 3)
    except OSError:
        specs["free_disk_gb"] = 0.0
    specs["passed"] = (
        specs["os_ok"]
        and specs["cpu_cores"] >= MIN_CPU_CORES
        and specs["ram_gb"] >= MIN_RAM_GB
        and specs["free_disk_gb"] >= MIN_FREE_DISK_GB
    )
    return specs


def requirements_failure_message(specs: dict) -> str:
    issues = []
    if not specs["os_ok"]:
        issues.append("• Supported OS: 64-bit Windows 10 or Windows 11")
    if specs["cpu_cores"] < MIN_CPU_CORES:
        issues.append(f"• CPU: at least {MIN_CPU_CORES} logical processor cores (detected {specs['cpu_cores']})")
    if specs["ram_gb"] < MIN_RAM_GB:
        detected = f"{specs['ram_gb']:.1f} GB" if specs["ram_gb"] else "could not be detected"
        issues.append(f"• RAM: at least {MIN_RAM_GB} GB (detected {detected})")
    if specs["free_disk_gb"] < MIN_FREE_DISK_GB:
        issues.append(f"• Free storage: at least {MIN_FREE_DISK_GB} GB (detected {specs['free_disk_gb']:.1f} GB)")
    return "\n".join(issues)


def find_installed_game() -> Path | None:
    # Prefer the launcher package folder, then the standard per-user install folder,
    # then a few common locations. No manual browse/scan step is required.
    candidates = [
        launcher_folder() / GAME_EXE,
        install_folder() / GAME_EXE,
        Path.home() / "Games" / "PandaRoyale" / GAME_EXE,
        Path(os.environ.get("PROGRAMFILES", r"C:\Program Files")) / "Panda Royale" / GAME_EXE,
        Path(os.environ.get("PROGRAMFILES(X86)", r"C:\Program Files (x86)")) / "Panda Royale" / GAME_EXE,
    ]
    for candidate in candidates:
        try:
            if candidate.is_file() and candidate.stat().st_size > 1024 * 1024:
                return candidate
        except OSError:
            pass
    return None


class Launcher:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Panda Royale Launcher")
        self.root.geometry("760x500")
        self.root.minsize(680, 460)
        self.root.configure(bg=BG)
        self.root.protocol("WM_DELETE_WINDOW", self.close_launcher)
        self.game_process = None
        self.rpc_client = None
        self.rpc_retry_pending = False
        self.dots = 0
        self.download_active = False
        self.game_path = None
        self.requirements_ok = True
        self._build_ui()
        self.root.after(150, self._check_minimum_requirements)
        self.root.after(250, self._startup_check)
        self.root.after(450, self._animate)

    def _build_ui(self):
        header = tk.Frame(self.root, bg=BG)
        header.pack(fill="x", padx=34, pady=(24, 6))
        tk.Label(header, text="PANDA", font=("Segoe UI", 13, "bold"), fg=CYAN, bg=BG).pack(anchor="w")
        tk.Label(header, text="ROYALE", font=("Segoe UI Black", 32, "bold"), fg=TEXT, bg=BG).pack(anchor="w")
        tk.Label(header, text="DROP IN. GEAR UP. BE THE LAST ONE STANDING.", font=("Segoe UI", 9, "bold"), fg=MUTED, bg=BG).pack(anchor="w")

        card = tk.Frame(self.root, bg=PANEL, highlightbackground="#292345", highlightthickness=1)
        card.pack(fill="both", expand=True, padx=34, pady=(15, 18))
        self.status_title = tk.Label(card, text="LAUNCHING PANDA ROYALE", font=("Segoe UI", 16, "bold"), fg=TEXT, bg=PANEL)
        self.status_title.pack(anchor="w", padx=24, pady=(22, 5))
        self.status_detail = tk.Label(card, text="Checking for an installed game...", font=("Segoe UI", 10), fg=MUTED, bg=PANEL, wraplength=620, justify="left")
        self.status_detail.pack(anchor="w", padx=24)
        self.progress = tk.Canvas(card, height=5, bg="#252b3d", highlightthickness=0)
        self.progress.pack(fill="x", padx=24, pady=(20, 16))
        self.bar = self.progress.create_rectangle(0, 0, 0, 5, fill=PURPLE, width=0)
        self.news = tk.Label(card, text="STATUS  •  Auto-detecting game installation", font=("Segoe UI", 9, "bold"), fg=CYAN, bg=PANEL)
        self.news.pack(anchor="w", padx=24, pady=(0, 16))

        buttons = tk.Frame(card, bg=PANEL)
        buttons.pack(fill="x", padx=24, pady=(0, 20), side="bottom")
        self.play_button = tk.Button(buttons, text="PLAY NOW", command=self.launch_game, font=("Segoe UI", 11, "bold"), bg=PURPLE, fg="white", activebackground="#7441d8", activeforeground="white", relief="flat", padx=26, pady=12, cursor="hand2", state="disabled")
        self.play_button.pack(side="left")
        self.install_button = tk.Button(buttons, text="INSTALL / REPAIR GAME", command=self.install_game, font=("Segoe UI", 10, "bold"), bg="#252b3d", fg=TEXT, activebackground="#343c54", activeforeground=TEXT, relief="flat", padx=18, pady=12, cursor="hand2")
        self.install_button.pack(side="left", padx=(10, 0))
        self.steam_button = tk.Button(buttons, text="ADD TO STEAM", command=self.add_to_steam, font=("Segoe UI", 10, "bold"), bg="#17344a", fg=TEXT, activebackground="#24536f", activeforeground=TEXT, relief="flat", padx=16, pady=12, cursor="hand2")
        self.steam_button.pack(side="left", padx=(10, 0))
        self.requirements_button = tk.Button(buttons, text="SYSTEM REQUIREMENTS", command=self.show_requirements, font=("Segoe UI", 9, "bold"), bg="#292345", fg=TEXT, activebackground="#3c3263", activeforeground=TEXT, relief="flat", padx=12, pady=12, cursor="hand2")
        self.requirements_button.pack(side="left", padx=(10, 0))
        self.bug_button = tk.Button(buttons, text="REPORT A BUG", command=self.open_bug_report, font=("Segoe UI", 9, "bold"), bg="#45243f", fg=TEXT, activebackground="#673455", activeforeground=TEXT, relief="flat", padx=12, pady=12, cursor="hand2")
        self.bug_button.pack(side="left", padx=(10, 0))
        tk.Label(buttons, text="EARLY ACCESS  •  WINDOWS", font=("Segoe UI", 8, "bold"), fg=MUTED, bg=PANEL).pack(side="right", anchor="s")

    def _check_minimum_requirements(self):
        self.system_specs = get_system_specs()
        specs = self.system_specs
        self.requirements_ok = bool(specs["passed"])
        if self.requirements_ok:
            return
        self.play_button.configure(state="disabled")
        self.install_button.configure(state="disabled")
        self.steam_button.configure(state="disabled")
        self.status_title.configure(text="PC DOES NOT MEET MINIMUM REQUIREMENTS")
        self.status_detail.configure(text="Playing and installing are blocked on this PC because one or more minimum requirements were not detected.")
        self.news.configure(text="STATUS  •  Minimum requirements check failed", fg="#ff7b91")
        details = requirements_failure_message(specs)
        messagebox.showerror(
            "Panda Royale — Minimum Requirements Not Met",
            "Panda Royale cannot be installed or launched on this PC yet.\n\n"
            + details
            + "\n\nThe launcher will remain available so you can view requirements and close it. "
              "Free up disk space or use a supported PC, then reopen the launcher. "
              "Graphics/OpenGL compatibility must be checked separately."
        )

    def _animate(self):
        self.dots = (self.dots + 1) % 4
        if self.download_active:
            self.status_title.configure(text="DOWNLOADING GAME" + "." * self.dots)
        elif self.game_path is None:
            self.status_title.configure(text="CHECKING GAME" + "." * self.dots)
        self.root.after(450, self._animate)

    def _startup_check(self):
        if self.download_active or not self.requirements_ok:
            return
        self.status_detail.configure(text="Looking in the launcher folder and common Panda Royale install locations...")
        self.root.update_idletasks()
        self.game_path = find_installed_game()
        if self.game_path:
            self.status_title.configure(text="READY TO DROP IN")
            self.status_detail.configure(text=f"Panda Royale was detected automatically.\nInstalled at: {self.game_path}")
            self.news.configure(text="STATUS  •  Game installed and ready", fg=CYAN)
            self.progress.coords(self.bar, 0, 0, max(1, self.progress.winfo_width()), 5)
            self.play_button.configure(state="normal")
            self.install_button.configure(text="REINSTALL / REPAIR")
        else:
            self.status_title.configure(text="GAME NOT INSTALLED")
            self.status_detail.configure(text="Panda Royale wasn't found on this PC. Please install the game. The launcher can download and install it for you.")
            self.news.configure(text="STATUS  •  Installation required", fg="#ffb454")
            self.play_button.configure(state="disabled")
            self.install_button.configure(text="DOWNLOAD & INSTALL")
            self.root.after(350, self._missing_game_prompt)

    def _missing_game_prompt(self):
        if self.game_path or self.download_active or not self.root.winfo_exists():
            return
        answer = messagebox.askyesno(
            "Panda Royale is not installed",
            "Panda Royale could not be detected on this PC.\n\nWould you like the launcher to download and install it now?\n\nThe game will be saved in your local AppData folder."
        )
        if answer:
            self.install_game()
        else:
            self.status_detail.configure(text="Game not installed. Select DOWNLOAD & INSTALL whenever you're ready.")
            self.news.configure(text="STATUS  •  Waiting for installation", fg="#ffb454")

    def install_game(self):
        specs = get_system_specs()
        self.requirements_ok = bool(specs["passed"])
        if not self.requirements_ok:
            messagebox.showerror("Minimum requirements not met", "Panda Royale installation is blocked.\n\n" + requirements_failure_message(specs))
            return
        if self.download_active:
            return
        if not messagebox.askyesno(
            "Install Panda Royale",
            "The launcher will download the latest Windows game build from the official Panda Royale GitHub Releases and install it for your Windows user. Continue?"
        ):
            return
        self.download_active = True
        self.play_button.configure(state="disabled")
        self.install_button.configure(state="disabled")
        self.status_detail.configure(text="Downloading the latest game build. Keep the launcher open...")
        self.news.configure(text="STATUS  •  Connecting to official release download", fg=CYAN)
        threading.Thread(target=self._download_worker, daemon=True).start()

    def _download_worker(self):
        target_dir = install_folder()
        temp_path = target_dir / (GAME_EXE + ".download")
        final_path = target_dir / GAME_EXE
        try:
            target_dir.mkdir(parents=True, exist_ok=True)
            request = urllib.request.Request(GAME_DOWNLOAD_URL, headers={"User-Agent": "PandaRoyaleLauncher/1.0"})
            with urllib.request.urlopen(request, timeout=30) as response, open(temp_path, "wb") as output:
                total = int(response.headers.get("Content-Length", "0") or "0")
                downloaded = 0
                while True:
                    chunk = response.read(1024 * 256)
                    if not chunk:
                        break
                    output.write(chunk)
                    downloaded += len(chunk)
                    if total > 0:
                        percent = min(100, int(downloaded * 100 / total))
                        self.root.after(0, lambda p=percent: self._set_download_progress(p))
            if temp_path.stat().st_size < 1024 * 1024:
                raise RuntimeError("The downloaded file is too small to be a valid game executable. A Windows build may not be published yet.")
            temp_path.replace(final_path)
            self.root.after(0, lambda p=final_path: self._download_success(p))
        except Exception as exc:
            try:
                temp_path.unlink(missing_ok=True)
            except OSError:
                pass
            self.root.after(0, lambda error=str(exc): self._download_failed(error))

    def _set_download_progress(self, percent):
        width = max(1, self.progress.winfo_width())
        self.progress.coords(self.bar, 0, 0, width * percent / 100, 5)
        self.news.configure(text=f"STATUS  •  Downloading game: {percent}%", fg=CYAN)

    def _download_success(self, path):
        self.download_active = False
        self.game_path = path
        self.install_button.configure(state="normal", text="REINSTALL / REPAIR", command=self.install_game)
        self.play_button.configure(state="normal")
        self.status_title.configure(text="INSTALLATION COMPLETE")
        self.status_detail.configure(text=f"Panda Royale is installed and ready.\nLocation: {path}")
        self.news.configure(text="STATUS  •  Game downloaded successfully", fg=CYAN)
        self.progress.coords(self.bar, 0, 0, max(1, self.progress.winfo_width()), 5)
        if messagebox.askyesno("Panda Royale installed", "Panda Royale is installed! Would you like to launch it now?"):
            self.launch_game()

    def _download_failed(self, error):
        self.download_active = False
        self.install_button.configure(state="normal", text="OPEN DOWNLOAD PAGE")
        self.install_button.configure(command=self.open_download_page)
        self.status_title.configure(text="DOWNLOAD UNAVAILABLE")
        self.status_detail.configure(text="The launcher couldn't download a game build. The latest release may not contain a Windows executable yet, or your connection may be blocking it.")
        self.news.configure(text="STATUS  •  Download failed", fg="#ff7b91")
        if messagebox.askyesno("Could not download Panda Royale", f"Automatic installation failed.\n\nDetails: {error}\n\nWould you like to open the official releases page to download it manually?"):
            self.open_download_page()

    def open_bug_report(self, title="Panda Royale bug report", details=""):
        body = (
            "## What happened?\\nDescribe the bug here.\\n\\n"
            "## Steps to reproduce\\n1.\\n2.\\n3.\\n\\n"
            "## Expected result\\n\\n## Actual result\\n\\n"
            "## System details\\n"
            f"- Launcher: Windows\\n- OS: {sys.platform}\\n"
            f"- Python: {sys.version.split()[0]}\\n"
            f"- Game path: {self.game_path or 'not detected'}\\n"
            f"- Additional details: {details or 'not provided'}\\n"
        )
        url = "https://github.com/PandaManDev/Panda-Royale/issues/new?" + urllib.parse.urlencode({"title": title, "body": body})
        try:
            webbrowser.open(url)
            self.status_detail.configure(text="Opened a pre-filled GitHub bug report in your browser. Review it and click Submit new issue on GitHub.")
            self.news.configure(text="STATUS  •  Bug report opened in browser", fg=CYAN)
        except Exception as exc:
            messagebox.showerror("Could not open bug report", f"Open this page manually:\\nhttps://github.com/PandaManDev/Panda-Royale/issues/new\\n\\n{exc}")

    def _check_game_startup(self):
        process = self.game_process
        if process is None:
            return
        code = process.poll()
        if code is not None:
            self.status_title.configure(text="GAME CLOSED DURING STARTUP")
            self.status_detail.configure(text=f"Panda Royale exited before it finished starting (exit code {code}). The black window may indicate a game startup error. Try reinstalling the latest build.")
            self.news.configure(text="STATUS  •  Game did not stay open", fg="#ff7b91")
            if code != 0 and messagebox.askyesno("Panda Royale closed unexpectedly", f"The game exited with code {code}. Would you like to open a pre-filled GitHub crash report?"):
                self.open_bug_report("Panda Royale crash / unexpected exit", f"Game exited during startup with code {code}")
            self.play_button.configure(state="normal")
            self.install_button.configure(state="normal")
            self.install_button.configure(text="REINSTALL / REPAIR", command=self.install_game)
            return
        self.status_title.configure(text="GAME IS RUNNING")
        self.status_detail.configure(text="Panda Royale's process is running. If its window stays black for more than a few seconds, close it and reinstall the latest build.")
        self.news.configure(text="STATUS  •  Game process is active", fg=CYAN)
        self.play_button.configure(state="normal")
        self.install_button.configure(state="normal", text="REINSTALL / REPAIR")

    def show_requirements(self):
        specs = get_system_specs()
        window = tk.Toplevel(self.root)
        window.title("Panda Royale — System Requirements")
        window.geometry("620x570")
        window.minsize(560, 500)
        window.configure(bg=BG)
        window.transient(self.root)

        tk.Label(window, text="SYSTEM REQUIREMENTS", font=("Segoe UI", 19, "bold"), fg=CYAN, bg=BG).pack(anchor="w", padx=26, pady=(24, 4))
        tk.Label(window, text="Windows PC • Provisional requirements for the current prototype", font=("Segoe UI", 9), fg=MUTED, bg=BG).pack(anchor="w", padx=26, pady=(0, 16))

        content = tk.Frame(window, bg=PANEL, highlightbackground="#292345", highlightthickness=1)
        content.pack(fill="both", expand=True, padx=24, pady=(0, 18))

        sections = [
            ("MINIMUM — ESTIMATED", [
                "OS: Windows 10 or 11, 64-bit",
                "CPU: 2-core processor around 2.0 GHz",
                "Memory: 4 GB RAM",
                "Graphics: GPU supporting OpenGL 3.3 / Godot GL Compatibility",
                "Storage: 1 GB free space for the game (more may be needed for updates)",
                "Internet: Broadband connection for online play",
            ]),
            ("RECOMMENDED — ESTIMATED", [
                "OS: Windows 10 or 11, 64-bit",
                "CPU: 4-core processor",
                "Memory: 8 GB RAM or more",
                "Graphics: Dedicated GPU or recent integrated graphics",
                "Storage: 2 GB free space",
            ]),
        ]
        for heading, lines in sections:
            tk.Label(content, text=heading, font=("Segoe UI", 11, "bold"), fg=PURPLE if heading.startswith("MINIMUM") else CYAN, bg=PANEL).pack(anchor="w", padx=20, pady=(16, 6))
            for line in lines:
                tk.Label(content, text="•  " + line, font=("Segoe UI", 9), fg=TEXT, bg=PANEL, wraplength=540, justify="left").pack(anchor="w", padx=22, pady=2)

        detected = (f"Detected on this PC: {specs['os_name']} • {specs['cpu_cores']} logical CPU cores • "
                    f"{specs['ram_gb']:.1f} GB RAM • {specs['free_disk_gb']:.1f} GB free storage.\n"
                    f"Automatic check: {'PASS' if specs['passed'] else 'FAIL'}.\n"
                    "Graphics/OpenGL support cannot be verified reliably by this check.")
        tk.Label(window, text=detected, font=("Segoe UI", 9, "bold"), fg=CYAN if specs["passed"] else "#ff7b91", bg=BG, wraplength=560, justify="left").pack(anchor="w", padx=26, pady=(0, 8))
        tk.Label(window, text="These are provisional estimates, not verified benchmarks. The launcher blocks play and game installation if Windows, CPU, RAM, or free-storage checks fail. Graphics/OpenGL compatibility must be checked separately.", font=("Segoe UI", 9), fg=MUTED, bg=BG, wraplength=560, justify="left").pack(anchor="w", padx=26, pady=(0, 12))
        tk.Button(window, text="CLOSE", command=window.destroy, font=("Segoe UI", 10, "bold"), bg=PURPLE, fg="white", activebackground="#7441d8", relief="flat", padx=24, pady=8).pack(anchor="e", padx=26, pady=(0, 20))

    def add_to_steam(self):
        game = self.game_path or find_installed_game()
        if not game:
            if messagebox.askyesno("Install Panda Royale first", "Panda Royale isn't installed yet. Would you like to download it before adding it to Steam?"):
                self.install_game()
            return

        # Steam does not expose a supported URI that silently registers an arbitrary
        # non-Steam executable. Copy the real EXE path and open Steam's Games view.
        try:
            self.root.clipboard_clear()
            self.root.clipboard_append(str(game))
            self.root.update()
        except tk.TclError as exc:
            messagebox.showerror("Could not copy game path", f"Copy this path manually instead:\n\n{game}\n\nDetails: {exc}")
            return

        try:
            webbrowser.open("steam://open/games")
        except Exception:
            pass

        messagebox.showinfo(
            "Add Panda Royale to Steam",
            "The game path has been copied to your clipboard.\n\n"
            "In Steam:\n"
            "1. Open the Games menu (or click + Add a Game).\n"
            "2. Choose 'Add a Non-Steam Game to My Library'.\n"
            "3. Click Browse and select PandaRoyale.exe at this path:\n\n"
            f"{game}\n\n"
            "4. Add the selected program. You can rename it to Panda Royale in your Steam Library.\n\n"
            "This adds a shortcut to your own Steam library; it does not publish the game on Steam."
        )

    def open_download_page(self):
        webbrowser.open(RELEASES_URL)

    def _discord_application_id(self):
        """Use the game's public application ID; overrides are for developer testing."""
        configured = os.environ.get("PANDA_ROYALE_DISCORD_APP_ID", "").strip()
        if configured:
            return configured
        try:
            from_file = (launcher_folder() / "discord_app_id.txt").read_text(encoding="utf-8").strip()
            if from_file:
                return from_file
        except OSError:
            pass
        return DISCORD_APPLICATION_ID

    def _start_discord_presence(self):
        """Use Discord desktop current session through its official local RPC IPC."""
        app_id = self._discord_application_id()
        if not app_id:
            self.news.configure(text="STATUS  •  Discord Rich Presence needs its game Application ID", fg=MUTED)
            return
        try:
            from pypresence import Presence
            client = Presence(app_id)
            client.connect()
            client.update(details="Playing Panda Royale", state="Dropping into the arena", start=int(time.time()), large_text="Panda Royale", small_text="Early Access")
            self.rpc_client = client
            self.news.configure(text="STATUS  •  Discord Rich Presence connected", fg=CYAN)
            self.status_detail.configure(text="Connected through the Discord desktop app existing session. No extra authorization or account permissions are requested.")
        except Exception as exc:
            self.rpc_client = None
            self.news.configure(text="STATUS  •  Discord RPC unavailable (game still launches)", fg=MUTED)
            self.status_detail.configure(text=f"Game launch is unaffected. Open the official Discord desktop app and sign in; Panda Royale will retry automatically. No password, user token, or OAuth grant is collected. ({exc})")
            if self.game_process is not None and self.game_process.poll() is None and not self.rpc_retry_pending:
                self.rpc_retry_pending = True
                self.root.after(10000, self._retry_discord_presence)

    def _retry_discord_presence(self):
        self.rpc_retry_pending = False
        if self.rpc_client is not None or self.game_process is None or self.game_process.poll() is not None:
            return
        self._start_discord_presence()

    def close_launcher(self):
        client = self.rpc_client
        self.rpc_client = None
        if client is not None:
            try:
                client.clear()
                client.close()
            except Exception:
                pass
        self.root.destroy()

    def launch_game(self):
        specs = get_system_specs()
        self.requirements_ok = bool(specs["passed"])
        if not self.requirements_ok:
            self.play_button.configure(state="disabled")
            self.install_button.configure(state="disabled")
            messagebox.showerror("Minimum requirements not met", "Panda Royale launch is blocked.\n\n" + requirements_failure_message(specs))
            return
        game = self.game_path or find_installed_game()
        if not game:
            self.game_path = None
            self._startup_check()
            return
        try:
            self.game_path = game
            self.status_title.configure(text="LAUNCHING GAME...")
            self.status_detail.configure(text="Starting Panda Royale. This launcher can stay open.")
            self.news.configure(text="STATUS  •  Launch request sent", fg=CYAN)
            self.game_process = subprocess.Popen([str(game)], cwd=str(game.parent))
            start_background_service(self.game_process.pid)
            self._start_discord_presence()
            self.play_button.configure(state="disabled")
            self.install_button.configure(state="disabled")
            self.status_title.configure(text="WAITING FOR GAME WINDOW...")
            self.status_detail.configure(text="Panda Royale is starting. This can take a little while on the first launch. Keep this launcher open while the game initializes.")
            self.news.configure(text="STATUS  •  Waiting for the game to finish starting", fg=CYAN)
            self.progress.coords(self.bar, 0, 0, max(1, self.progress.winfo_width()) * 0.35, 5)
            self.root.after(1200, self._check_game_startup)
        except OSError as exc:
            messagebox.showerror("Could not launch Panda Royale", str(exc))
            self.status_title.configure(text="LAUNCH FAILED")
            self.status_detail.configure(text="The detected game could not be started. Try reinstalling it.")
            self.news.configure(text="STATUS  •  Launch failed", fg="#ff7b91")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--background-service":
        try:
            raise SystemExit(run_background_service(int(sys.argv[2])))
        except (ValueError, OSError):
            raise SystemExit(2)
    Launcher().root.mainloop()
