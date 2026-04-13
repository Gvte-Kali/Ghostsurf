#!/usr/bin/env python3
"""
GhostSurf — systray PyQt6
"""
import sys
import subprocess
import threading
from pathlib import Path

try:
    from PyQt6.QtWidgets import (
        QApplication, QSystemTrayIcon, QMenu,
        QWidget, QVBoxLayout, QHBoxLayout,
        QLabel, QPushButton, QFrame
    )
    from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor, QFont, QCursor
    from PyQt6.QtCore import QTimer, Qt, QThread, pyqtSignal, QPoint
except ImportError:
    print("PyQt6 requis:")
    print("  pip install PyQt6")
    print("  # ou")
    print("  sudo apt install python3-pyqt6")
    print("  sudo dnf install python3-qt6")
    print("  sudo pacman -S python-pyqt6")
    sys.exit(1)

GHOSTSURF_BIN = Path(__file__).parent.parent / "ghostsurf"
if not GHOSTSURF_BIN.exists():
    GHOSTSURF_BIN = Path("/usr/bin/ghostsurf")


# ── Icônes SVG inline ─────────────────────────────────────────────────────────

ICON_ACTIVE = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#1a1a2e"/>
  <circle cx="32" cy="32" r="22" fill="none" stroke="#2ecc71" stroke-width="2"/>
  <circle cx="32" cy="32" r="14" fill="none" stroke="#2ecc71" stroke-width="1.5" opacity="0.6"/>
  <circle cx="32" cy="32" r="6"  fill="#2ecc71"/>
  <line x1="32" y1="2"  x2="32" y2="10" stroke="#2ecc71" stroke-width="2"/>
  <line x1="32" y1="54" x2="32" y2="62" stroke="#2ecc71" stroke-width="2"/>
  <line x1="2"  y1="32" x2="10" y2="32" stroke="#2ecc71" stroke-width="2"/>
  <line x1="54" y1="32" x2="62" y2="32" stroke="#2ecc71" stroke-width="2"/>
</svg>
"""

ICON_INACTIVE = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#1a1a2e"/>
  <circle cx="32" cy="32" r="22" fill="none" stroke="#e74c3c" stroke-width="2"/>
  <circle cx="32" cy="32" r="14" fill="none" stroke="#e74c3c" stroke-width="1.5" opacity="0.4"/>
  <circle cx="32" cy="32" r="6"  fill="#e74c3c" opacity="0.7"/>
  <line x1="20" y1="20" x2="44" y2="44" stroke="#e74c3c" stroke-width="2.5"/>
  <line x1="44" y1="20" x2="20" y2="44" stroke="#e74c3c" stroke-width="2.5"/>
</svg>
"""

ICON_LOADING = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#1a1a2e"/>
  <circle cx="32" cy="32" r="22" fill="none" stroke="#f39c12" stroke-width="2"/>
  <circle cx="32" cy="32" r="6"  fill="#f39c12" opacity="0.8"/>
</svg>
"""


def svg_to_icon(svg_str: str, size: int = 22) -> QIcon:
    """Convertit une chaîne SVG en QIcon."""
    try:
        from PyQt6.QtSvg import QSvgRenderer
        from PyQt6.QtCore import QByteArray
        renderer = QSvgRenderer(QByteArray(svg_str.encode()))
        pix = QPixmap(size, size)
        pix.fill(Qt.GlobalColor.transparent)
        painter = QPainter(pix)
        renderer.render(painter)
        painter.end()
        return QIcon(pix)
    except ImportError:
        # Fallback si QtSvg absent — cercle coloré simple
        pix = QPixmap(size, size)
        pix.fill(Qt.GlobalColor.transparent)
        p = QPainter(pix)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if "2ecc71" in svg_str:
            p.setBrush(QColor("#2ecc71"))
        elif "e74c3c" in svg_str:
            p.setBrush(QColor("#e74c3c"))
        else:
            p.setBrush(QColor("#f39c12"))
        p.setPen(Qt.PenStyle.NoPen)
        p.drawEllipse(2, 2, size - 4, size - 4)
        p.end()
        return QIcon(pix)


# ── Worker thread ─────────────────────────────────────────────────────────────

class GhostSurfWorker(QThread):
    """Exécute les commandes ghostsurf en arrière-plan."""
    finished = pyqtSignal(bool, str)

    def __init__(self, command: str):
        super().__init__()
        self.command = command

    def run(self):
        try:
            result = subprocess.run(
                ["pkexec", str(GHOSTSURF_BIN), self.command],
                capture_output=True, text=True, timeout=120
            )
            success = result.returncode == 0
            output = result.stdout + result.stderr
            self.finished.emit(success, output)
        except subprocess.TimeoutExpired:
            self.finished.emit(False, "Timeout")
        except Exception as e:
            self.finished.emit(False, str(e))


class StatusWorker(QThread):
    """Récupère le statut en arrière-plan."""
    status_ready = pyqtSignal(dict)

    def run(self):
        try:
            result = subprocess.run(
                [str(GHOSTSURF_BIN), "status"],
                capture_output=True, text=True, timeout=10
            )
            data = {}
            for line in result.stdout.splitlines():
                if ":" in line:
                    k, _, v = line.partition(":")
                    data[k.strip()] = v.strip()
            self.status_ready.emit(data)
        except Exception:
            self.status_ready.emit({})


# ── Fenêtre status ────────────────────────────────────────────────────────────

class StatusWindow(QWidget):
    """Petite fenêtre flottante affichant le statut détaillé."""

    def __init__(self):
        super().__init__()
        self.setWindowTitle("GhostSurf")
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self._build_ui()
        self.setFixedWidth(280)

    def _build_ui(self):
        # Conteneur principal avec style
        container = QFrame(self)
        container.setObjectName("container")
        container.setStyleSheet("""
            QFrame#container {
                background: #0d1117;
                border: 1px solid #30363d;
                border-radius: 12px;
            }
        """)

        layout = QVBoxLayout(container)
        layout.setContentsMargins(16, 14, 16, 14)
        layout.setSpacing(8)

        # Header
        header = QHBoxLayout()
        self.icon_label = QLabel("●")
        self.icon_label.setStyleSheet("color: #e74c3c; font-size: 12px;")
        title = QLabel("GhostSurf")
        title.setStyleSheet("""
            color: #e6edf3;
            font-size: 13px;
            font-weight: bold;
            font-family: monospace;
        """)
        close_btn = QPushButton("✕")
        close_btn.setFixedSize(20, 20)
        close_btn.setStyleSheet("""
            QPushButton {
                background: transparent;
                color: #8b949e;
                border: none;
                font-size: 11px;
            }
            QPushButton:hover { color: #e6edf3; }
        """)
        close_btn.clicked.connect(self.hide)
        header.addWidget(self.icon_label)
        header.addWidget(title)
        header.addStretch()
        header.addWidget(close_btn)
        layout.addLayout(header)

        # Séparateur
        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet("color: #30363d;")
        layout.addWidget(sep)

        # Infos
        self.rows = {}
        for key in ["Tor", "Firewall", "IP", "Distro", "Backend fw", "SELinux", "Snapshot"]:
            row = QHBoxLayout()
            lbl = QLabel(key)
            lbl.setStyleSheet("color: #8b949e; font-size: 11px; font-family: monospace;")
            lbl.setFixedWidth(80)
            val = QLabel("—")
            val.setStyleSheet("color: #e6edf3; font-size: 11px; font-family: monospace;")
            val.setWordWrap(True)
            row.addWidget(lbl)
            row.addWidget(val)
            self.rows[key] = val
            layout.addLayout(row)

        # Boutons
        sep2 = QFrame()
        sep2.setFrameShape(QFrame.Shape.HLine)
        sep2.setStyleSheet("color: #30363d;")
        layout.addWidget(sep2)

        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(8)

        self.toggle_btn = QPushButton("▶ Activer")
        self.toggle_btn.setStyleSheet(self._btn_style("#238636", "#2ea043"))

        newid_btn = QPushButton("⟳ New ID")
        newid_btn.setStyleSheet(self._btn_style("#1f6feb", "#388bfd"))
        newid_btn.clicked.connect(self._new_id)

        btn_layout.addWidget(self.toggle_btn)
        btn_layout.addWidget(newid_btn)
        layout.addLayout(btn_layout)

        # Layout externe pour la transparence
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.addWidget(container)

    def _btn_style(self, bg: str, hover: str) -> str:
        return f"""
            QPushButton {{
                background: {bg};
                color: #ffffff;
                border: none;
                border-radius: 6px;
                padding: 5px 10px;
                font-size: 11px;
                font-family: monospace;
            }}
            QPushButton:hover {{ background: {hover}; }}
            QPushButton:pressed {{ opacity: 0.8; }}
        """

    def update_status(self, data: dict, active: bool):
        self.rows["Tor"].setText(data.get("Tor", "—"))
        self.rows["Firewall"].setText(data.get("Firewall", "—"))
        self.rows["IP"].setText(data.get("IP", "—"))
        self.rows["Distro"].setText(data.get("Distro", "—"))
        self.rows["Backend fw"].setText(data.get("Backend fw", "—"))
        self.rows["SELinux"].setText(data.get("SELinux", "—"))
        self.rows["Snapshot"].setText(data.get("Snapshot", "—"))

        if active:
            self.icon_label.setStyleSheet("color: #2ecc71; font-size: 12px;")
            self.toggle_btn.setText("■ Désactiver")
            self.toggle_btn.setStyleSheet(self._btn_style("#da3633", "#f85149"))
        else:
            self.icon_label.setStyleSheet("color: #e74c3c; font-size: 12px;")
            self.toggle_btn.setText("▶ Activer")
            self.toggle_btn.setStyleSheet(self._btn_style("#238636", "#2ea043"))

    def _btn_style(self, bg: str, hover: str) -> str:
        return f"""
            QPushButton {{
                background: {bg};
                color: #ffffff;
                border: none;
                border-radius: 6px;
                padding: 5px 10px;
                font-size: 11px;
                font-family: monospace;
            }}
            QPushButton:hover {{ background: {hover}; }}
        """

    def _new_id(self):
        worker = GhostSurfWorker("newid")
        worker.start()

    def show_near_tray(self):
        """Affiche la fenêtre près du curseur."""
        cursor_pos = QCursor.pos()
        self.adjustSize()
        x = cursor_pos.x() - self.width() // 2
        y = cursor_pos.y() - self.height() - 10
        # Reste dans l'écran
        screen = QApplication.primaryScreen().geometry()
        x = max(0, min(x, screen.width() - self.width()))
        y = max(0, min(y, screen.height() - self.height()))
        self.move(x, y)
        self.show()
        self.raise_()
        self.activateWindow()


# ── Systray principal ─────────────────────────────────────────────────────────

class GhostSurfTray(QSystemTrayIcon):

    def __init__(self, app: QApplication):
        super().__init__()
        self.app = app
        self._active = False
        self._loading = False
        self._worker = None
        self.status_window = StatusWindow()

        self._build_menu()
        self.setIcon(svg_to_icon(ICON_INACTIVE))
        self.setToolTip("GhostSurf — inactif")
        self.activated.connect(self._on_activated)
        self.show()

        # Polling statut toutes les 10s
        self.timer = QTimer()
        self.timer.timeout.connect(self._refresh_status)
        self.timer.start(10000)
        self._refresh_status()

    def _build_menu(self):
        self.menu = QMenu()
        self.menu.setStyleSheet("""
            QMenu {
                background: #0d1117;
                color: #e6edf3;
                border: 1px solid #30363d;
                border-radius: 8px;
                padding: 4px;
                font-family: monospace;
                font-size: 12px;
            }
            QMenu::item {
                padding: 6px 16px;
                border-radius: 4px;
            }
            QMenu::item:selected { background: #21262d; }
            QMenu::separator {
                height: 1px;
                background: #30363d;
                margin: 4px 8px;
            }
        """)

        self.status_action = self.menu.addAction("○  GhostSurf — inactif")
        self.status_action.setEnabled(False)
        self.menu.addSeparator()

        self.toggle_action = self.menu.addAction("▶  Activer")
        self.toggle_action.triggered.connect(self._toggle)

        self.newid_action = self.menu.addAction("⟳  Nouvelle identité")
        self.newid_action.triggered.connect(self._new_identity)

        self.menu.addSeparator()
        self.menu.addAction("◈  Statut détaillé").triggered.connect(
            self.status_window.show_near_tray
        )
        self.menu.addSeparator()
        self.menu.addAction("✕  Quitter").triggered.connect(self.app.quit)
        self.setContextMenu(self.menu)

    def _on_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            if self.status_window.isVisible():
                self.status_window.hide()
            else:
                self.status_window.show_near_tray()

    def _refresh_status(self):
        worker = StatusWorker()
        worker.status_ready.connect(self._on_status)
        worker.start()
        self._status_worker = worker

    def _on_status(self, data: dict):
        tor = data.get("Tor", "inactif")
        ip  = data.get("IP", "—")
        self._active = (tor == "actif")

        if self._loading:
            return

        if self._active:
            self.setIcon(svg_to_icon(ICON_ACTIVE))
            self.status_action.setText(f"●  Actif — {ip}")
            self.toggle_action.setText("■  Désactiver")
            self.setToolTip(f"GhostSurf actif\nIP: {ip}")
        else:
            self.setIcon(svg_to_icon(ICON_INACTIVE))
            self.status_action.setText("○  Inactif")
            self.toggle_action.setText("▶  Activer")
            self.setToolTip("GhostSurf — inactif")

        self.status_window.update_status(data, self._active)
        self.status_window.toggle_btn.clicked.disconnect() if \
            self.status_window.toggle_btn.receivers(
                self.status_window.toggle_btn.clicked) > 0 else None
        self.status_window.toggle_btn.clicked.connect(self._toggle)

    def _toggle(self):
        if self._loading:
            return
        self._loading = True
        self.setIcon(svg_to_icon(ICON_LOADING))
        self.status_action.setText("○  En cours...")
        self.toggle_action.setEnabled(False)

        cmd = "stop" if self._active else "start"
        self._worker = GhostSurfWorker(cmd)
        self._worker.finished.connect(self._on_command_done)
        self._worker.start()

    def _on_command_done(self, success: bool, output: str):
        self._loading = False
        self.toggle_action.setEnabled(True)
        self._refresh_status()

    def _new_identity(self):
        if not self._active:
            return
        self.newid_action.setEnabled(False)
        worker = GhostSurfWorker("newid")
        worker.finished.connect(lambda ok, _: (
            self.newid_action.setEnabled(True),
            self._refresh_status()
        ))
        worker.start()


# ── Point d'entrée ────────────────────────────────────────────────────────────

def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    app.setApplicationName("GhostSurf")

    if not QSystemTrayIcon.isSystemTrayAvailable():
        print("Systray non disponible sur ce bureau")
        sys.exit(1)

    tray = GhostSurfTray(app)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()