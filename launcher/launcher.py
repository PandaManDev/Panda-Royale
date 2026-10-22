import os
import subprocess
import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import messagebox

APP_NAME = "PANDA ROYALE"
GAME_EXE = "PandaRoyale.exe"
BG = "#090b14"
PANEL = "#111626"
PURPLE = "#8b5cf6"
CYAN = "#42e8ff"
TEXT = "#f4f5ff"
MUTED = "#9aa4bd"


def app_folder() -> Path:
    # PyInstaller one-file launchers live beside the game, not in the temp extraction folder.
    return Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent


class Launcher:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Panda Royale Launcher")
        self.root.geometry("760x480")
        self.root.minsize(680, 440)
        self.root.configure(bg=BG)
        self.root.protocol("WM_DELETE_WINDOW", self.root.destroy)
        self.game_process = None
        self.dots = 0
        self._build_ui()
        self.root.after(250, self._startup_check)
        self.root.after(450, self._animate)

    def _build_ui(self):
        header = tk.Frame(self.root, bg=BG)
        header.pack(fill="x", padx=34, pady=(26, 8))
        tk.Label(header, text="PANDA", font=("Segoe UI", 13, "bold"), fg=CYAN, bg=BG).pack(anchor="w")
        tk.Label(header, text="ROYALE", font=("Segoe UI Black", 32, "bold"), fg=TEXT, bg=BG).pack(anchor="w")
        tk.Label(header, text="DROP IN. GEAR UP. BE THE LAST ONE STANDING.", font=("Segoe UI", 9, "bold"), fg=MUTED, bg=BG).pack(anchor="w", pady=(1, 0))

        card = tk.Frame(self.root, bg=PANEL, highlightbackground="#292345", highlightthickness=1)
        card.pack(fill="both", expand=True, padx=34, pady=(18, 18))
        self.status_title = tk.Label(card, text="LAUNCHING PANDA ROYALE", font=("Segoe UI", 16, "bold"), fg=TEXT, bg=PANEL)
        self.status_title.pack(anchor="w", padx=24, pady=(24, 5))
        self.status_detail = tk.Label(card, text="Preparing your game...", font=("Segoe UI", 10), fg=MUTED, bg=PANEL)
        self.status_detail.pack(anchor="w", padx=24)
        self.progress = tk.Canvas(card, height=5, bg="#252b3d", highlightthickness=0)
        self.progress.pack(fill="x", padx=24, pady=(22, 18))
        self.bar = self.progress.create_rectangle(0, 0, 0, 5, fill=PURPLE, width=0)
        self.news = tk.Label(card, text="STATUS  •  Checking local game files", font=("Segoe UI", 9, "bold"), fg=CYAN, bg=PANEL)
        self.news.pack(anchor="w", padx=24, pady=(0, 18))

        buttons = tk.Frame(card, bg=PANEL)
        buttons.pack(fill="x", padx=24, pady=(0, 22), side="bottom")
        self.play_button = tk.Button(buttons, text="PLAY NOW", command=self.launch_game, font=("Segoe UI", 11, "bold"), bg=PURPLE, fg="white", activebackground="#7441d8", activeforeground="white", relief="flat", padx=26, pady=12, cursor="hand2", state="disabled")
        self.play_button.pack(side="left")
        self.recheck_button = tk.Button(buttons, text="CHECK FILES", command=self._startup_check, font=("Segoe UI", 10, "bold"), bg="#252b3d", fg=TEXT, activebackground="#343c54", activeforeground=TEXT, relief="flat", padx=18, pady=12, cursor="hand2")
        self.recheck_button.pack(side="left", padx=(10, 0))
        tk.Label(buttons, text="EARLY ACCESS  •  WINDOWS", font=("Segoe UI", 8, "bold"), fg=MUTED, bg=PANEL).pack(side="right", anchor="s")

    def _animate(self):
        self.dots = (self.dots + 1) % 4
        if not self.play_button["state"] == "normal":
            self.status_title.configure(text="WAITING FOR GAME" + "." * self.dots)
            self.progress.update_idletasks()
            width = max(1, self.progress.winfo_width())
            x = (self.dots + 1) * width / 5
            self.progress.coords(self.bar, max(0, x - width * 0.18), 0, min(width, x + width * 0.18), 5)
        self.root.after(450, self._animate)

    def _startup_check(self):
        game = app_folder() / GAME_EXE
        if game.is_file():
            self.status_title.configure(text="READY TO DROP IN")
            self.status_detail.configure(text="Panda Royale is installed and ready to launch.")
            self.news.configure(text="STATUS  •  Game executable found", fg=CYAN)
            self.progress.coords(self.bar, 0, 0, max(1, self.progress.winfo_width()), 5)
            self.play_button.configure(state="normal")
        else:
            self.status_title.configure(text="WAITING FOR GAME FILES")
            self.status_detail.configure(text=f"Place {GAME_EXE} in this same folder as the launcher.")
            self.news.configure(text="STATUS  •  Game executable missing", fg="#ff7b91")
            self.play_button.configure(state="disabled")
            messagebox.showwarning("Panda Royale files missing", f"Could not find {GAME_EXE}.\n\nKeep the launcher and game executable together, then select CHECK FILES.")

    def launch_game(self):
        game = app_folder() / GAME_EXE
        if not game.is_file():
            self._startup_check()
            return
        try:
            self.status_title.configure(text="LAUNCHING GAME...")
            self.status_detail.configure(text="Starting Panda Royale. This window can stay open.")
            self.news.configure(text="STATUS  •  Launch request sent", fg=CYAN)
            self.game_process = subprocess.Popen([str(game)], cwd=str(game.parent))
            self.status_title.configure(text="GAME LAUNCHED")
            self.status_detail.configure(text="Have fun out there. Good luck, and watch the storm!")
            self.news.configure(text="STATUS  •  Game process started", fg=CYAN)
        except OSError as exc:
            messagebox.showerror("Could not launch Panda Royale", str(exc))
            self.status_title.configure(text="LAUNCH FAILED")
            self.status_detail.configure(text="Check that the game executable is present and valid.")
            self.news.configure(text="STATUS  •  Launch failed", fg="#ff7b91")


if __name__ == "__main__":
    Launcher().root.mainloop()
