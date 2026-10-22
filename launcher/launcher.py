import os
import subprocess
import sys
import threading
import urllib.request
import webbrowser
from pathlib import Path
import tkinter as tk
from tkinter import messagebox

APP_NAME = "PANDA ROYALE"
GAME_EXE = "PandaRoyale.exe"
GAME_DOWNLOAD_URL = "https://github.com/PandaManDev/Panda-Royale/releases/latest/download/PandaRoyale.exe"
RELEASES_URL = "https://github.com/PandaManDev/Panda-Royale/releases/latest"
BG = "#090b14"
PANEL = "#111626"
PURPLE = "#8b5cf6"
CYAN = "#42e8ff"
TEXT = "#f4f5ff"
MUTED = "#9aa4bd"


def launcher_folder() -> Path:
    return Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent


def install_folder() -> Path:
    base = os.environ.get("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
    return Path(base) / "PandaRoyale"


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
        self.root.protocol("WM_DELETE_WINDOW", self.root.destroy)
        self.game_process = None
        self.dots = 0
        self.download_active = False
        self.game_path = None
        self._build_ui()
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
        tk.Label(buttons, text="EARLY ACCESS  •  WINDOWS", font=("Segoe UI", 8, "bold"), fg=MUTED, bg=PANEL).pack(side="right", anchor="s")

    def _animate(self):
        self.dots = (self.dots + 1) % 4
        if self.download_active:
            self.status_title.configure(text="DOWNLOADING GAME" + "." * self.dots)
        elif self.game_path is None:
            self.status_title.configure(text="CHECKING GAME" + "." * self.dots)
        self.root.after(450, self._animate)

    def _startup_check(self):
        if self.download_active:
            return
        self.status_detail.configure(text="Looking in the launcher folder and common Panda Royale install locations...")
        self.root.update_idletasks()
        self.game_path = find_installed_game()
        if self.game_path:
            self.status_title.configure(text="READY TO DROP IN")
            self.status_detail.configure(text=f"Panda Royale was detected automatically.\\nInstalled at: {self.game_path}")
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
            "Panda Royale could not be detected on this PC.\\n\\nWould you like the launcher to download and install it now?\\n\\nThe game will be saved in your local AppData folder."
        )
        if answer:
            self.install_game()
        else:
            self.status_detail.configure(text="Game not installed. Select DOWNLOAD & INSTALL whenever you're ready.")
            self.news.configure(text="STATUS  •  Waiting for installation", fg="#ffb454")

    def install_game(self):
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
        self.install_button.configure(state="normal", text="REINSTALL / REPAIR")
        self.play_button.configure(state="normal")
        self.status_title.configure(text="INSTALLATION COMPLETE")
        self.status_detail.configure(text=f"Panda Royale is installed and ready.\\nLocation: {path}")
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
        if messagebox.askyesno("Could not download Panda Royale", f"Automatic installation failed.\\n\\nDetails: {error}\\n\\nWould you like to open the official releases page to download it manually?"):
            self.open_download_page()

    def _check_game_startup(self):
        process = self.game_process
        if process is None:
            return
        code = process.poll()
        if code is not None:
            self.status_title.configure(text="GAME CLOSED DURING STARTUP")
            self.status_detail.configure(text=f"Panda Royale exited before it finished starting (exit code {code}). The black window may indicate a game startup error. Try reinstalling the latest build.")
            self.news.configure(text="STATUS  •  Game did not stay open", fg="#ff7b91")
            self.play_button.configure(state="normal")
            self.install_button.configure(state="normal")
            self.install_button.configure(text="REINSTALL / REPAIR", command=self.install_game)
            return
        self.status_title.configure(text="GAME IS RUNNING")
        self.status_detail.configure(text="Panda Royale's process is running. If its window stays black for more than a few seconds, close it and reinstall the latest build.")
        self.news.configure(text="STATUS  •  Game process is active", fg=CYAN)
        self.play_button.configure(state="normal")
        self.install_button.configure(state="normal", text="REINSTALL / REPAIR")

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
            messagebox.showerror("Could not copy game path", f"Copy this path manually instead:\\n\\n{game}\\n\\nDetails: {exc}")
            return

        try:
            webbrowser.open("steam://open/games")
        except Exception:
            pass

        messagebox.showinfo(
            "Add Panda Royale to Steam",
            "The game path has been copied to your clipboard.\\n\\n"
            "In Steam:\\n"
            "1. Open the Games menu (or click + Add a Game).\\n"
            "2. Choose 'Add a Non-Steam Game to My Library'.\\n"
            "3. Click Browse and select PandaRoyale.exe at this path:\\n\\n"
            f"{game}\\n\\n"
            "4. Add the selected program. You can rename it to Panda Royale in your Steam Library.\\n\\n"
            "This adds a shortcut to your own Steam library; it does not publish the game on Steam."
        )

    def open_download_page(self):
        webbrowser.open(RELEASES_URL)

    def launch_game(self):
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
    Launcher().root.mainloop()
