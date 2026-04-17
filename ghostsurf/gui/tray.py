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
        QLabel, QPushButton, QFrame, QTextEdit,
        QSizeGrip
    )
    from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor, QCursor
    from PyQt6.QtCore import QTimer, Qt, QThread, pyqtSignal, QPoint
except ImportError:
    print("PyQt6 requis:")
    print("  sudo apt install python3-pyqt6 python3-pyqt6.qtsvg")
    sys.exit(1)

GHOSTSURF_BIN = Path(__file__).parent.parent / "ghostsurf"
if not GHOSTSURF_BIN.exists():
    GHOSTSURF_BIN = Path("/usr/bin/ghostsurf")

# Mapping code pays → drapeau emoji
COUNTRY_FLAGS = {
    "AF":"🇦🇫","AL":"🇦🇱","DZ":"🇩🇿","AD":"🇦🇩","AO":"🇦🇴","AR":"🇦🇷","AM":"🇦🇲",
    "AU":"🇦🇺","AT":"🇦🇹","AZ":"🇦🇿","BS":"🇧🇸","BH":"🇧🇭","BD":"🇧🇩","BY":"🇧🇾",
    "BE":"🇧🇪","BZ":"🇧🇿","BJ":"🇧🇯","BT":"🇧🇹","BO":"🇧🇴","BA":"🇧🇦","BW":"🇧🇼",
    "BR":"🇧🇷","BN":"🇧🇳","BG":"🇧🇬","BF":"🇧🇫","BI":"🇧🇮","CV":"🇨🇻","KH":"🇰🇭",
    "CM":"🇨🇲","CA":"🇨🇦","CF":"🇨🇫","TD":"🇹🇩","CL":"🇨🇱","CN":"🇨🇳","CO":"🇨🇴",
    "KM":"🇰🇲","CG":"🇨🇬","CD":"🇨🇩","CR":"🇨🇷","HR":"🇭🇷","CU":"🇨🇺","CY":"🇨🇾",
    "CZ":"🇨🇿","DK":"🇩🇰","DJ":"🇩🇯","DO":"🇩🇴","EC":"🇪🇨","EG":"🇪🇬","SV":"🇸🇻",
    "GQ":"🇬🇶","ER":"🇪🇷","EE":"🇪🇪","SZ":"🇸🇿","ET":"🇪🇹","FJ":"🇫🇯","FI":"🇫🇮",
    "FR":"🇫🇷","GA":"🇬🇦","GM":"🇬🇲","GE":"🇬🇪","DE":"🇩🇪","GH":"🇬🇭","GR":"🇬🇷",
    "GT":"🇬🇹","GN":"🇬🇳","GW":"🇬🇼","GY":"🇬🇾","HT":"🇭🇹","HN":"🇭🇳","HU":"🇭🇺",
    "IS":"🇮🇸","IN":"🇮🇳","ID":"🇮🇩","IR":"🇮🇷","IQ":"🇮🇶","IE":"🇮🇪","IL":"🇮🇱",
    "IT":"🇮🇹","JM":"🇯🇲","JP":"🇯🇵","JO":"🇯🇴","KZ":"🇰🇿","KE":"🇰🇪","KI":"🇰🇮",
    "KW":"🇰🇼","KG":"🇰🇬","LA":"🇱🇦","LV":"🇱🇻","LB":"🇱🇧","LS":"🇱🇸","LR":"🇱🇷",
    "LY":"🇱🇾","LI":"🇱🇮","LT":"🇱🇹","LU":"🇱🇺","MG":"🇲🇬","MW":"🇲🇼","MY":"🇲🇾",
    "MV":"🇲🇻","ML":"🇲🇱","MT":"🇲🇹","MH":"🇲🇭","MR":"🇲🇷","MU":"🇲🇺","MX":"🇲🇽",
    "FM":"🇫🇲","MD":"🇲🇩","MC":"🇲🇨","MN":"🇲🇳","ME":"🇲🇪","MA":"🇲🇦","MZ":"🇲🇿",
    "MM":"🇲🇲","NA":"🇳🇦","NR":"🇳🇷","NP":"🇳🇵","NL":"🇳🇱","NZ":"🇳🇿","NI":"🇳🇮",
    "NE":"🇳🇪","NG":"🇳🇬","NO":"🇳🇴","OM":"🇴🇲","PK":"🇵🇰","PW":"🇵🇼","PA":"🇵🇦",
    "PG":"🇵🇬","PY":"🇵🇾","PE":"🇵🇪","PH":"🇵🇭","PL":"🇵🇱","PT":"🇵🇹","QA":"🇶🇦",
    "RO":"🇷🇴","RU":"🇷🇺","RW":"🇷🇼","KN":"🇰🇳","LC":"🇱🇨","VC":"🇻🇨","WS":"🇼🇸",
    "SM":"🇸🇲","ST":"🇸🇹","SA":"🇸🇦","SN":"🇸🇳","RS":"🇷🇸","SC":"🇸🇨","SL":"🇸🇱",
    "SG":"🇸🇬","SK":"🇸🇰","SI":"🇸🇮","SB":"🇸🇧","SO":"🇸🇴","ZA":"🇿🇦","SS":"🇸🇸",
    "ES":"🇪🇸","LK":"🇱🇰","SD":"🇸🇩","SR":"🇸🇷","SE":"🇸🇪","CH":"🇨🇭","SY":"🇸🇾",
    "TW":"🇹🇼","TJ":"🇹🇯","TZ":"🇹🇿","TH":"🇹🇭","TL":"🇹🇱","TG":"🇹🇬","TO":"🇹🇴",
    "TT":"🇹🇹","TN":"🇹🇳","TR":"🇹🇷","TM":"🇹🇲","TV":"🇹🇻","UG":"🇺🇬","UA":"🇺🇦",
    "AE":"🇦🇪","GB":"🇬🇧","US":"🇺🇸","UY":"🇺🇾","UZ":"🇺🇿","VU":"🇻🇺","VE":"🇻🇪",
    "VN":"🇻🇳","YE":"🇾🇪","ZM":"🇿🇲","ZW":"🇿🇼","EU":"🇪🇺","UN":"🇺🇳",
}

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
        color = QColor("#2ecc71") if "2ecc71" in svg_str else \
                QColor("#e74c3c") if "e74c3c" in svg_str else \
                QColor("#f39c12")
        p.setBrush(color)
        p.setPen(Qt.PenStyle.NoPen)
        p.drawEllipse(2, 2, size - 4, size - 4)
        p.end()
        return QIcon(pix)


# ── Workers ───────────────────────────────────────────────────────────────────

class GhostSurfWorker(QThread):
    finished = pyqtSignal(bool, str)

    def __init__(self, command: str):
        super().__init__()
        self.command = command

    def run(self):
        try:
            result = subprocess.run(
                ["sudo", str(GHOSTSURF_BIN), self.command],
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
                ["sudo", str(GHOSTSURF_BIN), "status"],
                capture_output=True, text=True, timeout=15
            )
            data = {}
            for line in result.stdout.splitlines():
                line = line.strip()
                if ":" in line and not line.startswith("─") \
                        and not line.startswith("GhostSurf"):
                    k, _, v = line.partition(":")
                    data[k.strip()] = v.strip()
            self.status_ready.emit(data)
        except Exception:
            self.status_ready.emit({})


class NewIdWorker(QThread):
    finished = pyqtSignal(bool, str)

    def run(self):
        try:
            result = subprocess.run(
                ["sudo", str(GHOSTSURF_BIN), "newid"],
                capture_output=True, text=True, timeout=120
            )
            self.finished.emit(result.returncode == 0, result.stdout + result.stderr)
        except Exception as e:
            self.finished.emit(False, str(e))


# ── Fenêtre status ────────────────────────────────────────────────────────────

class StatusWindow(QWidget):

    toggle_requested = pyqtSignal()
    newid_requested  = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.setWindowTitle("GhostSurf")
        # Fenêtre normale — déplaçable et redimensionnable
        self.setWindowFlags(
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool
        )
        self.setMinimumWidth(300)
        self.setMinimumHeight(300)
        self.resize(320, 420)
        self._build_ui()
        self._apply_style()

    def _apply_style(self):
        self.setStyleSheet("""
            QWidget {
                background: #0d1117;
                color: #e6edf3;
                font-family: monospace;
            }
            QFrame#sep {
                color: #21262d;
                background: #21262d;
                max-height: 1px;
            }
        """)

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 14, 16, 14)
        layout.setSpacing(6)

        # Header — point + drapeau + IP
        header = QHBoxLayout()
        self.dot = QLabel("●")
        self.dot.setStyleSheet("color: #e74c3c; font-size: 14px;")

        self.flag_label = QLabel("")
        self.flag_label.setStyleSheet("""
            font-size: 14px;
            font-family: 'Noto Color Emoji', 'Segoe UI Emoji', 'Apple Color Emoji';
        """)

        self.ip_banner = QLabel("—")
        self.ip_banner.setStyleSheet("""
            color: #ffffff;
            font-size: 14px;
            font-weight: bold;
            font-family: sans-serif;
        """)

        header.addWidget(self.dot)
        header.addSpacing(6)
        header.addWidget(self.flag_label)
        header.addSpacing(4)
        header.addWidget(self.ip_banner, 1)
        layout.addLayout(header)

        self._add_sep(layout)

        # Champs status
        self.rows = {}
        fields = [
            ("Tor",        "Statut Tor"),
            ("Firewall",   "Firewall"),
            ("Distro",     "Distribution"),
            ("Backend fw", "Backend"),
            ("SELinux",    "SELinux"),
            ("Snapshot",   "Dernier snapshot"),
        ]
        for key, label in fields:
            row = QHBoxLayout()
            lbl = QLabel(label)
            lbl.setFixedWidth(120)
            lbl.setStyleSheet("color: #8b949e; font-size: 11px;")
            val = QLabel("—")
            val.setStyleSheet("color: #e6edf3; font-size: 11px;")
            val.setWordWrap(True)
            row.addWidget(lbl)
            row.addWidget(val, 1)
            self.rows[key] = val
            layout.addLayout(row)

        self._add_sep(layout)

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

        self._add_sep(layout)

        # Zone logs
        self.log_area = QTextEdit()
        self.log_area.setReadOnly(True)
        self.log_area.setMinimumHeight(70)
        self.log_area.setStyleSheet("""
            QTextEdit {
                background: #010409;
                color: #8b949e;
                border: 1px solid #21262d;
                border-radius: 4px;
                font-family: monospace;
                font-size: 10px;
                padding: 4px;
            }
        """)
        layout.addWidget(self.log_area, 1)

        # Grip de redimensionnement
        grip_row = QHBoxLayout()
        grip_row.addStretch()
        grip = QSizeGrip(self)
        grip.setStyleSheet("background: transparent;")
        grip_row.addWidget(grip)
        layout.addLayout(grip_row)

    def _add_sep(self, layout):
        sep = QFrame()
        sep.setObjectName("sep")
        sep.setFrameShape(QFrame.Shape.HLine)
        layout.addWidget(sep)

    def _btn(self, bg: str, hover: str) -> str:
        return f"""
            QPushButton {{
                background: {bg}; color: #fff;
                border: none; border-radius: 6px;
                padding: 6px 12px; font-size: 12px;
            }}
            QPushButton:hover {{ background: {hover}; }}
            QPushButton:disabled {{ background: #21262d; color: #8b949e; }}
        """

    def update_status(self, data: dict, active: bool, loading: bool = False):
        ip   = data.get("IP Tor", data.get("IP", ""))
        pays = data.get("Pays", "")
        flag = COUNTRY_FLAGS.get(pays.upper(), "") if pays else ""

        if ip and ip not in ("?", "—", ""):
            self.flag_label.setText(flag)
            self.ip_banner.setText(f"{ip}  {pays}")
            self.ip_banner.setStyleSheet("""
                color: #ffffff;
                font-size: 14px;
                font-weight: bold;
                font-family: sans-serif;
            """)
        else:
            self.flag_label.setText("")
            self.ip_banner.setText("Pas de connexion Tor")
            self.ip_banner.setStyleSheet(
                "color: #8b949e; font-size: 13px; font-family: sans-serif;"
            )

        for key, widget in self.rows.items():
            widget.setText(data.get(key, "—"))

        if loading:
            self.dot.setStyleSheet("color: #f39c12; font-size: 14px;")
            self.toggle_btn.setText("...  En cours")
            self.toggle_btn.setEnabled(False)
            self.toggle_btn.setStyleSheet(self._btn("#21262d", "#21262d"))
            return

        if active:
            self.dot.setStyleSheet("color: #2ecc71; font-size: 14px;")
            self.toggle_btn.setText("■  Désactiver")
            self.toggle_btn.setStyleSheet(self._btn("#da3633", "#f85149"))
        else:
            self.dot.setStyleSheet("color: #e74c3c; font-size: 14px;")
            self.toggle_btn.setText("▶  Activer")
            self.toggle_btn.setStyleSheet(self._btn("#238636", "#2ea043"))

        self.toggle_btn.setEnabled(True)
        self.newid_btn.setEnabled(active and not loading)

    def add_log(self, msg: str, level: str = "info"):
        from PyQt6.QtCore import QDateTime
        colors = {
            "ok":    "#2ecc71",
            "error": "#e74c3c",
            "warn":  "#f39c12",
            "info":  "#8b949e",
        }
        color = colors.get(level, "#8b949e")
        ts = QDateTime.currentDateTime().toString("HH:mm:ss")
        self.log_area.append(
            f'<span style="color:#444d56">[{ts}]</span> '
            f'<span style="color:{color}">{msg}</span>'
        )
        sb = self.log_area.verticalScrollBar()
        sb.setValue(sb.maximum())

    def show_near_cursor(self):
        screen = QApplication.primaryScreen().availableGeometry()
        pos = QCursor.pos()
        x = max(screen.x(), min(pos.x() - self.width() // 2,
                                screen.x() + screen.width() - self.width()))
        y = max(screen.y(), min(pos.y() - self.height() - 12,
                                screen.y() + screen.height() - self.height()))
        self.move(x, y)
        self.show()
        self.raise_()
        self.activateWindow()


# ── Systray ───────────────────────────────────────────────────────────────────

class GhostSurfTray(QSystemTrayIcon):

    def __init__(self, app: QApplication):
        super().__init__()
        self.app            = app
        self._active        = False
        self._loading       = False
        self._worker        = None
        self._newid_worker  = None
        self._status_worker = None
        self._prev_active   = None

        self.win = StatusWindow()
        self.win.toggle_requested.connect(self._toggle)
        self.win.newid_requested.connect(self._new_identity)

        self._build_menu()
        self.setIcon(svg_to_icon(ICON_INACTIVE))
        self.setToolTip("GhostSurf — inactif")
        self.activated.connect(self._on_activated)
        self.show()

        # Timer rapide — vérifie juste si Tor est actif (sans appel réseau)
        self.timer_fast = QTimer()
        self.timer_fast.timeout.connect(self._refresh_quick)
        self.timer_fast.start(2000)

        # Timer lent — status complet avec IP
        self.timer_slow = QTimer()
        self.timer_slow.timeout.connect(self._refresh)
        self.timer_slow.start(15000)
        self._refresh()

    def _worker_running(self, worker) -> bool:
        """Vérifie si un worker est encore actif sans crasher."""
        try:
            return worker is not None and worker.isRunning()
        except RuntimeError:
            return False

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
        self.menu.addAction("✕  Quitter").triggered.connect(self._quit)
        self.setContextMenu(self.menu)

    def _on_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            if self.win.isVisible():
                self.win.hide()
            else:
                self.win.show_near_cursor()

    def _refresh_quick(self):
        """Vérifie juste si Tor est actif — rapide, sans appel réseau."""
        try:
            if self._loading or self._worker_running(self._status_worker):
                return
            result = subprocess.run(
                ["systemctl", "is-active", "tor@default"],
                capture_output=True, text=True, timeout=2
            )
            active = result.returncode == 0
            if active != self._active and not self._loading:
                self._refresh()
        except Exception:
            pass

    def _refresh(self):
        if self._loading or self._worker_running(self._status_worker):
            return
        self._status_worker = StatusWorker()
        self._status_worker.status_ready.connect(self._on_status)
        self._status_worker.start()

    def _on_status(self, data: dict):
        try:
            if self._loading:
                return

            ip   = data.get("IP Tor", data.get("IP", "—"))
            pays = data.get("Pays", "")
            flag = COUNTRY_FLAGS.get(pays.upper(), "") if pays else ""
            tor  = data.get("Tor", "inactif")
            self._active = (tor == "actif")

            if self._active:
                label = f"●  {flag} {ip}" if ip and ip not in ("—", "?") \
                        else "●  Actif"
                self.setIcon(svg_to_icon(ICON_ACTIVE))
                self.toggle_item.setText("■  Désactiver")
                self.newid_item.setEnabled(True)
                self.setToolTip(f"GhostSurf actif\n{flag} {ip}  {pays}".strip())
            else:
                label = "○  GhostSurf — inactif"
                self.setIcon(svg_to_icon(ICON_INACTIVE))
                self.toggle_item.setText("▶  Activer")
                self.newid_item.setEnabled(False)
                self.setToolTip("GhostSurf — inactif")

            self.status_item.setText(label)
            self.win.update_status(data, self._active)

            if self._prev_active is not None \
                    and self._prev_active != self._active:
                self.win.add_log(
                    f"GhostSurf {'actif' if self._active else 'arrêté'}",
                    "ok" if self._active else "warn"
                )
            self._prev_active = self._active

        except Exception as e:
            print(f"Erreur _on_status: {e}")

    def _toggle(self):
        if self._loading:
            return
        self._loading = True
        cmd = "stop" if self._active else "start"
        self.setIcon(svg_to_icon(ICON_LOADING))
        self.status_item.setText("○  En cours...")
        self.toggle_item.setEnabled(False)
        self.win.update_status({}, self._active, loading=True)
        self.win.add_log(
            f"{'Arrêt' if self._active else 'Démarrage'} en cours...", "warn"
        )
        self._worker = GhostSurfWorker(cmd)
        self._worker.finished.connect(self._on_done)
        self._worker.start()

    def _on_done(self, success: bool, _output: str):
        self._loading = False
        self.toggle_item.setEnabled(True)
        self.win.add_log(
            "Commande terminée" if success else "Erreur",
            "ok" if success else "error"
        )
        if self._worker:
            self._worker.wait(3000)
        self._refresh()

    def _new_identity(self):
        if not self._active or self._loading:
            return
        if self._worker_running(self._newid_worker):
            return
        self.newid_item.setEnabled(False)
        self.win.add_log("Nouvelle identité en cours...", "warn")
        self._newid_worker = NewIdWorker()
        self._newid_worker.finished.connect(self._on_newid_done)
        self._newid_worker.start()

    def _on_newid_done(self, ok: bool, _output: str):
        self.newid_item.setEnabled(True)
        self.win.add_log(
            "Nouvelle identité obtenue" if ok else "Erreur newid",
            "ok" if ok else "error"
        )
        if self._newid_worker:
            self._newid_worker.wait(3000)
        self._refresh()

    def _quit(self):
        """Stoppe GhostSurf si actif puis ferme le tray proprement."""
        if self._active:
            self.win.add_log("Arrêt GhostSurf avant fermeture...", "warn")
            self.status_item.setText("○  Fermeture en cours...")
            try:
                subprocess.run(
                    ["sudo", str(GHOSTSURF_BIN), "stop"],
                    timeout=60
                )
            except Exception as e:
                print(f"Erreur stop: {e}")
        self.timer_fast.stop()
        self.timer_slow.stop()
        self.app.quit()


# ── Main ──────────────────────────────────────────────────────────────────────

def _handle_exception(exc_type, exc_value, exc_traceback):
    """Handler global — log le crash et quitte proprement."""
    import traceback
    import datetime

    log_dir = os.path.expanduser("~/.local/share/ghostsurf")
    os.makedirs(log_dir, exist_ok=True)
    crash_log = os.path.join(log_dir, "crash.log")

    with open(crash_log, "a") as f:
        f.write(f"\n[{datetime.datetime.now()}] CRASH\n")
        traceback.print_exception(exc_type, exc_value, exc_traceback, file=f)

    traceback.print_exception(exc_type, exc_value, exc_traceback)
    print(f"\nCrash log : {crash_log}")

    try:
        QApplication.quit()
    except Exception:
        pass
    sys.exit(1)


def main():
    sys.excepthook = _handle_exception

    if os.geteuid() == 0:
        print("Le systray ne doit pas être lancé en root.")
        print("Lance : ghostsurf tray  (sans sudo)")
        sys.exit(1)

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    app.setApplicationName("GhostSurf")

    def qt_message_handler(mode, context, message):
        if "QThread" in message and "Destroyed" in message:
            pass  # Supprime le warning QThread verbeux
        else:
            print(f"Qt: {message}")

    from PyQt6.QtCore import qInstallMessageHandler
    qInstallMessageHandler(qt_message_handler)

    tray = GhostSurfTray(app)

    if not tray.isVisible():
        print("Impossible d'afficher le systray.")
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()