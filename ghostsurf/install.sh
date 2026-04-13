#!/usr/bin/env bash
# install.sh — installation de GhostSurf
set -e

INSTALL_BIN="/usr/bin/ghostsurf"
INSTALL_LIB="/usr/lib/ghostsurf"
INSTALL_GUI="/usr/lib/ghostsurf/gui"
INSTALL_CONF="/etc/ghostsurf"
STATE_DIR="/var/lib/ghostsurf/snapshots"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ $EUID -eq 0 ]] || { echo "Installation requiert root"; exit 1; }

echo "Installation de GhostSurf..."

# Répertoires
mkdir -p "$INSTALL_LIB/core" "$INSTALL_LIB/assets" "$INSTALL_GUI" \
         "$INSTALL_CONF" "$STATE_DIR"

# Fichiers
cp -r "$SRC_DIR/core/"  "$INSTALL_LIB/"
cp -r "$SRC_DIR/assets/" "$INSTALL_LIB/"
cp -r "$SRC_DIR/gui/"   "$INSTALL_GUI/"
cp    "$SRC_DIR/ghostsurf" "$INSTALL_BIN"
chmod +x "$INSTALL_BIN"

# Config par défaut
[[ -f "$INSTALL_CONF/ghostsurf.conf" ]] || \
    cp "$SRC_DIR/config/ghostsurf.conf.default" "$INSTALL_CONF/ghostsurf.conf"

# Systemd
cp "$SRC_DIR/sys-units/"*.service /etc/systemd/system/
systemctl daemon-reload

# Corrige les chemins dans le binaire installé
sed -i "s|GHOSTSURF_DIR=\".*\"|GHOSTSURF_DIR=\"$INSTALL_LIB\"|" "$INSTALL_BIN"

echo "GhostSurf installé. Lancez: sudo ghostsurf check"
