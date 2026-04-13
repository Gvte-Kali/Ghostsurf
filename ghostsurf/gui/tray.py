#!/usr/bin/env python3
"""
ghostsurf systray — PyQt6
Affiche l'état Tor et permet start/stop depuis la barre système
"""
import sys, subprocess, json
from pathlib import Path

try:
    from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QWidget
    from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor
    from PyQt6.QtCore import QTimer, Qt, QSize
except ImportError:
    print("PyQt6 requis: pip install PyQt6  ou  dnf/apt install python3-pyqt6")
    sys.exit(1)

GHOSTSURF_BIN = Path(__file__).parent.parent / "ghostsurf"

def make_icon(active: bool) -> QIcon:
    """Génère une icône circulaire verte/rouge selon l'état."""
    pix = QPixmap(22, 22)
    pix.fill(Qt.GlobalColor.transparent)
    p = QPainter(pix)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    color = QColor("#2ecc71") if active else QColor("#e74c3c")
    p.setBrush(color)
    p.setPen(Qt.PenStyle.NoPen)
    p.drawEllipse(2, 2, 18, 18)
    p.end()
    return QIcon(pix)

def run_ghostsurf(*args) -> str:
    try:
        r = subprocess.run(
            ["pkexec", str(GHOSTSURF_BIN), *args],
            capture_output=True, text=True, timeout=60
        )
        return r.stdout + r.stderr
    except Exception as e:
        return str(e)

def get_status() -> dict:
    try:
        r = subprocess.run(
            [str(GHOSTSURF_BIN), "status"],
            capture_output=True, text=True, timeout=10
        )
        lines = r.stdout.strip().splitlines()
        result = {}
        for line in lines:
            if ":" in line:
                k, _, v = line.partition(":")
                result[k.strip()] = v.strip()
        return result
    except Exception:
        return {}

class GhostSurfTray(QSystemTrayIcon):
    def __init__(self, app: QApplication):
        super().__init__()
        self.app = app
        self._active = False
        self._build_menu()
        self.setIcon(make_icon(False))
        self.setToolTip("GhostSurf — inactif")
        self.show()

        self.timer = QTimer()
        self.timer.timeout.connect(self.refresh)
        self.timer.start(8000)
        self.refresh()

    def _build_menu(self):
        self.menu = QMenu()
        self.status_action = self.menu.addAction("● Statut: vérification...")
        self.status_action.setEnabled(False)
        self.menu.addSeparator()

        self.toggle_action = self.menu.addAction("▶  Activer GhostSurf")
        self.toggle_action.triggered.connect(self.toggle)

        self.newid_action = self.menu.addAction("⟳  Nouvelle identité")
        self.newid_action.triggered.connect(lambda: run_ghostsurf("newid"))

        self.menu.addSeparator()
        self.menu.addAction("✕  Quitter").triggered.connect(self.app.quit)
        self.setContextMenu(self.menu)

    def refresh(self):
        st = get_status()
        tor = st.get("Tor", "inactif")
        ip  = st.get("IP", "—")
        self._active = (tor == "actif")

        self.setIcon(make_icon(self._active))
        if self._active:
            self.status_action.setText(f"● Actif — {ip}")
            self.toggle_action.setText("■  Désactiver GhostSurf")
            self.setToolTip(f"GhostSurf actif\nIP: {ip}")
        else:
            self.status_action.setText("○ Inactif")
            self.toggle_action.setText("▶  Activer GhostSurf")
            self.setToolTip("GhostSurf — inactif")

    def toggle(self):
        cmd = "stop" if self._active else "start"
        self.status_action.setText("... en cours")
        run_ghostsurf(cmd)
        self.refresh()

def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    tray = GhostSurfTray(app)
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
