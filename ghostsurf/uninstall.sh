#!/usr/bin/env bash
set -e
[[ $EUID -eq 0 ]] || { echo "Requiert root"; exit 1; }
echo "Désinstallation GhostSurf..."
sudo ghostsurf stop 2>/dev/null || true
systemctl disable ghostsurf 2>/dev/null || true
rm -f /usr/bin/ghostsurf
rm -rf /usr/lib/ghostsurf
rm -f /etc/systemd/system/ghostsurf*.service
rm -f /etc/sudoers.d/ghostsurf
systemctl daemon-reload
echo "Désinstallé. Les snapshots sont conservés dans /var/lib/ghostsurf"
echo "Supprimez manuellement avec: rm -rf /var/lib/ghostsurf"
