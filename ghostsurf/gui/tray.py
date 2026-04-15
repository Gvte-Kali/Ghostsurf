#!/usr/bin/env python3
"""
GhostSurf — systray PyQt6
Lance sans sudo : ghostsurf tray
"""
import sys
import os
import subprocess
from pathlib import Path

try:
    from PyQt6.QtWidgets import (
        QApplication, QSystemTrayIcon, QMenu,
        QWidget, QVBoxLayout, QHBoxLayout,
        QLabel, QPushButton, QFrame
    )
    from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor, QCursor
    from PyQt6.QtCore import QTimer, Qt, QThread, pyqtSignal
except ImportError:
    print("PyQt6 requis:")
    print("  sudo apt install python3-pyqt6 python3-pyqt6.qtsvg")
    print("  sudo dnf install python3-qt6")
    print("  sudo pacman -S python-pyqt6")
    sys.exit(1)

GHOSTSURF_BIN = Path(__file__).parent.parent / "ghostsurf"
if not GHOSTSURF_BIN.exists():
    GHOSTSURF_BIN = Path("/usr/bin/ghostsurf")

ICON_ACTIVE = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#0d1117"/>
  <circle cx="32" cy="32" r="22" fill="none" stroke="#2ecc71" stroke-width="2"/>
  <circle cx="32" cy="32" r="14" fill="none" stroke="#2ecc71" stroke-width="1.5" opacity="0.6"/>
  <circle cx="32" cy="32" r="6" fill="#2ecc71"/>
  <line x1="32" y1="2"  x2="32" y2="10" stroke="#2ecc71" stroke-width="2"/>
  <line x1="32" y1="54" x2="32" y2="62" stroke="#2ecc71" stroke-width="2"/>
  <line x1="2"  y1="32" x2="10" y2="32" stroke="#2ecc71" stroke-width="2"/>
  <line x1="54" y1="32" x2="62" y2="32" stroke="#2ecc71" stroke-width="2"/>
</svg>
"""

ICON_INACTIVE = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#0d1117"/>
  <circle cx="32" cy="32" r="22" fill="none" stroke="#e74c3c" stroke-width="2"/>
  <circle cx="32" cy="32" r="14" fill="none" stroke="#e74c3c" stroke-width="1.5" opacity="0.4"/>
  <circle cx="32" cy="32" r="6" fill="#e74c3c" opacity="0.7"/>
  <line x1="20" y1="20" x2="44" y2="44" stroke="#e74c3c" stroke-width="2.5"/>
  <line x1="44" y1="20" x2="20" y2="44" stroke="#e74c3c" stroke-width="2.5"/>
</svg>
"""

ICON_LOADING = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="30" fill="#0d1117"/>
  <circle cx="32" cy="32" r="22" fill="none" stroke="#f39c12" stroke-width="2"/>
  <circle cx="32" cy="32" r="6" fill="#f39c12" opacity="0.8"/>
</svg>
"""


def svg_to_icon(svg_str: str, size: int = 22) -> QIcon:
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
        pix = QPixmap(size, size)
        pix.fill(Qt.GlobalColor.transparent)
        p = QPainter(pix)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if "2ecc71" in svg_str:
            color = QColor("#2ecc71")
        elif "e74c3c" in svg_str:
            color = QColor("#e74c3c")
        else:
            color = QColor("#f39c12")
        p.setBrush(color)
        p.setPen(Qt.PenStyle.NoPen)
        p.drawEllipse(2, 2, size - 4, size - 4)
        p.end()
        return QIcon(pix)


class GhostSurfWorker(QThread):
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
            self.finished.emit(result.returncode == 0, result.stdout + result.stderr)
        except subprocess.TimeoutExpired:
            self.finished.emit(False, "Timeout")
        except Exception as e:
            self.finished.emit(False, str(e))


class StatusWorker(QThread):
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


class StatusWindow(QWidget):

    toggle_requested = pyqtSignal()
    newid_requested  = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.setWindowTitle("GhostSurf")
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setFixedWidth(290)
        self._build_ui()

    def _build_ui(self):
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
        layout.setSpacing(6)

        # Header
        header = QHBoxLayout()
        self.dot = QLabel("●")
        self.dot.setStyleSheet("color: #e74c3c; font-size: 11px;")
        title = QLabel("GhostSurf")
        title.setStyleSheet(
            "color: #e6edf3; font-size: 13px; font-weight: bold; font-family: monospace;"
        )
        close_btn = QPushButton("✕")
        close_btn.setFixedSize(18, 18)
        close_btn.setStyleSheet("""
            QPushButton {
                background: transparent; color: #8b949e;
                border: none; font-size: 10px;
            }
            QPushButton:hover { color: #e6edf3; }
        """)
        close_btn.clicked.connect(self.hide)
        header.addWidget(self.dot)
        header.addSpacing(4)
        header.addWidget(title)
        header.addStretch()
        header.addWidget(close_btn)
        layout.addLayout(header)

        # Séparateur
        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.HLine)
        sep.setStyleSheet("color: #21262d;")
        layout.addWidget(sep)

        # Rows
        self.rows = {}
        fields = [
            ("Tor",        "Statut Tor"),
            ("IP",         "IP publique"),
            ("Firewall",   "Firewall"),
            ("Distro",     "Distribution"),
            ("Backend fw", "Backend"),
            ("SELinux",    "SELinux"),
            ("Snapshot",   "Dernier snapshot"),
        ]
        for key, label in fields:
            row = QHBoxLayout()
            lbl = QLabel(label)
            lbl.setFixedWidth(110)
            lbl.setStyleSheet(
                "color: #8b949e; font-size: 11px; font-family: monospace;"
            )
            val = QLabel("—")
            val.setStyleSheet(
                "color: #e6edf3; font-size: 11px; font-family: monospace;"
            )
            val.setWordWrap(True)
            row.addWidget(lbl)
            row.addWidget(val, 1)
            self.rows[key] = val
            layout.addLayout(row)

        # Séparateur
        sep2 = QFrame()
        sep2.setFrameShape(QFrame.Shape.HLine)
        sep2.setStyleSheet("color: #21262d;")
        layout.addWidget(sep2)

        # Boutons
        btn_row = QHBoxLayout()
        btn_row.setSpacing(8)

        self.toggle_btn = QPushButton("▶  Activer")
        self.toggle_btn.setStyleSheet(self._btn("#238636", "#2ea043"))
        self.toggle_btn.clicked.connect(self.toggle_requested.emit)

        self.newid_btn = QPushButton("⟳  New ID")
        self.newid_btn.setStyleSheet(self._btn("#1f6feb", "#388bfd"))
        self.newid_btn.clicked.connect(self.newid_requested.emit)

        btn_row.addWidget(self.toggle_btn)
        btn_row.addWidget(self.newid_btn)
        layout.addLayout(btn_row)

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.addWidget(container)

    def _btn(self, bg: str, hover: str) -> str:
        return f"""
            QPushButton {{
                background: {bg}; color: #fff;
                border: none; border-radius: 6px;
                padding: 5px 10px; font-size: 11px;
                font-family: monospace;
            }}
            QPushButton:hover {{ background: {hover}; }}
            QPushButton:disabled {{ background: #21262d; color: #8b949e; }}
        """

    def update_status(self, data: dict, active: bool, loading: bool = False):
        for key, widget in self.rows.items():
            widget.setText(data.get(key, "—"))

        if loading:
            self.dot.setStyleSheet("color: #f39c12; font-size: 11px;")
            self.toggle_btn.setText("...  En cours")
            self.toggle_btn.setEnabled(False)
            self.toggle_btn.setStyleSheet(self._btn("#21262d", "#21262d"))
            return

        if active:
            self.dot.setStyleSheet("color: #2ecc71; font-size: 11px;")
            self.toggle_btn.setText("■  Désactiver")
            self.toggle_btn.setStyleSheet(self._btn("#da3633", "#f85149"))
        else:
            self.dot.setStyleSheet("color: #e74c3c; font-size: 11px;")
            self.toggle_btn.setText("▶  Activer")
            self.toggle_btn.setStyleSheet(self._btn("#238636", "#2ea043"))

        self.toggle_btn.setEnabled(True)
        self.newid_btn.setEnabled(active)

    def show_near_cursor(self):
        self.adjustSize()
        pos = QCursor.pos()
        screen = QApplication.primaryScreen().availableGeometry()
        x = max(screen.x(), min(pos.x() - self.width() // 2,
                                screen.x() + screen.width() - self.width()))
        y = max(screen.y(), min(pos.y() - self.height() - 12,
                                screen.y() + screen.height() - self.height()))
        self.move(x, y)
        self.show()
        self.raise_()
        self.activateWindow()


class GhostSurfTray(QSystemTrayIcon):

    def __init__(self, app: QApplication):
        super().__init__()
        self.app      = app
        self._active  = False
        self._loading = False
        self._worker  = None
        self._status_worker = None

        self.win = StatusWindow()
        self.win.toggle_requested.connect(self._toggle)
        self.win.newid_requested.connect(self._new_identity)

        self._build_menu()
        self.setIcon(svg_to_icon(ICON_INACTIVE))
        self.setToolTip("GhostSurf — inactif")
        self.activated.connect(self._on_activated)
        self.show()

        self.timer = QTimer()
        self.timer.timeout.connect(self._refresh)
        self.timer.start(10000)
        self._refresh()

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
            QMenu::item { padding: 6px 16px; border-radius: 4px; }
            QMenu::item:selected { background: #21262d; }
            QMenu::separator {
                height: 1px; background: #30363d; margin: 4px 8px;
            }
        """)

        self.status_item = self.menu.addAction("○  GhostSurf — inactif")
        self.status_item.setEnabled(False)
        self.menu.addSeparator()

        self.toggle_item = self.menu.addAction("▶  Activer")
        self.toggle_item.triggered.connect(self._toggle)

        self.newid_item = self.menu.addAction("⟳  Nouvelle identité")
        self.newid_item.triggered.connect(self._new_identity)

        self.menu.addSeparator()
        self.menu.addAction("◈  Statut détaillé").triggered.connect(
            self.win.show_near_cursor
        )
        self.menu.addSeparator()
        self.menu.addAction("✕  Quitter").triggered.connect(self.app.quit)
        self.setContextMenu(self.menu)

    def _on_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            if self.win.isVisible():
                self.win.hide()
            else:
                self.win.show_near_cursor()

    def _refresh(self):
        if self._loading:
            return
        worker = StatusWorker()
        worker.status_ready.connect(self._on_status)
        worker.start()
        self._status_worker = worker

    def _on_status(self, data: dict):
        if self._loading:
            return
        tor = data.get("Tor", "inactif")
        ip  = data.get("IP", "—")
        self._active = (tor == "actif")

        if self._active:
            self.setIcon(svg_to_icon(ICON_ACTIVE))
            self.status_item.setText(f"●  Actif — {ip}")
            self.toggle_item.setText("■  Désactiver")
            self.newid_item.setEnabled(True)
            self.setToolTip(f"GhostSurf actif\nIP : {ip}")
        else:
            self.setIcon(svg_to_icon(ICON_INACTIVE))
            self.status_item.setText("○  Inactif")
            self.toggle_item.setText("▶  Activer")
            self.newid_item.setEnabled(False)
            self.setToolTip("GhostSurf — inactif")

        self.win.update_status(data, self._active)

    def _toggle(self):
        if self._loading:
            return
        self._loading = True
        self.setIcon(svg_to_icon(ICON_LOADING))
        self.status_item.setText("○  En cours...")
        self.toggle_item.setEnabled(False)
        self.win.update_status({}, self._active, loading=True)

        cmd = "stop" if self._active else "start"
        self._worker = GhostSurfWorker(cmd)
        self._worker.finished.connect(self._on_done)
        self._worker.start()

    def _on_done(self, success: bool, _output: str):
        self._loading = False
        self.toggle_item.setEnabled(True)
        self._refresh()

    def _new_identity(self):
        if not self._active or self._loading:
            return
        self.newid_item.setEnabled(False)
        worker = GhostSurfWorker("newid")
        worker.finished.connect(
            lambda ok, _: (
                self.newid_item.setEnabled(True),
                self._refresh()
            )
        )
        worker.start()


def main():
    # Vérifie qu'on n'est pas root
    if os.geteuid() == 0:
        print("Le systray ne doit pas être lancé en root.")
        print("Lance : ghostsurf tray  (sans sudo)")
        sys.exit(1)

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    app.setApplicationName("GhostSurf")

    tray = GhostSurfTray(app)

    # DBus warning est normal sur certains environnements — pas bloquant
    if not tray.isVisible():
        print("Impossible d'afficher le systray.")
        print("Vérifie que ton bureau est démarré et que DISPLAY est défini.")
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()