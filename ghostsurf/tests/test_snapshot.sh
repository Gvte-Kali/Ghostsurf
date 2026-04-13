#!/usr/bin/env bash
set -e
[[ $EUID -eq 0 ]] || { echo "Requiert root: sudo bash tests/test_snapshot.sh"; exit 1; }

GHOSTSURF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export STATE_DIR="/var/lib/ghostsurf"
source "$GHOSTSURF_DIR/core/logger.sh"
source "$GHOSTSURF_DIR/core/distro.sh"
source "$GHOSTSURF_DIR/core/snapshot.sh"
source "$GHOSTSURF_DIR/tests/helpers.sh"

echo "=== Tests snapshot.sh ==="

distro_detect

# Test création
snap=$(snapshot_create)
assert "snapshot_create retourne un chemin" "$(test -d "$snap" && echo ok)" "ok"
assert "timestamp présent" "$(test -f "$snap/timestamp" && echo ok)" "ok"
assert "resolv.conf sauvegardé" "$(test -f "$snap/resolv.conf" && echo ok)" "ok"
assert "hostname sauvegardé" "$(test -f "$snap/hostname" && echo ok)" "ok"
assert "ip-link.txt sauvegardé" "$(test -f "$snap/ip-link.txt" && echo ok)" "ok"

# Test listing
list=$(snapshot_list)
assert "snapshot_list non vide" "$(test -n "$list" && echo ok)" "ok"

# Test limite 5 snapshots
for i in {1..6}; do snapshot_create >/dev/null; sleep 1; done
count=$(ls "$SNAPSHOT_BASE" | wc -l)
assert "maximum 5 snapshots" "$(test "$count" -le 5 && echo ok)" "ok"

# Recrée un snapshot frais pour les tests restore
snap=$(snapshot_create)

# Test restore hostname
orig_hostname=$(hostname)
hostname "test-ghostsurf-123"
assert "hostname changé pour test" "$(hostname)" "test-ghostsurf-123"
snapshot_restore "$snap"
assert "hostname restauré après restore" "$(hostname)" "$orig_hostname"

# Test restore resolv.conf
# Sauvegarde le contenu original
orig_dns=$(cat /etc/resolv.conf)

# Modifie avec une valeur clairement factice pour le test
echo "# ghostsurf-test-marker" > /etc/resolv.conf

# Restore via snapshot
snapshot_restore "$snap"

# Vérifie que l'original est bien revenu
assert "resolv.conf restauré" "$(cat /etc/resolv.conf)" "$orig_dns"

print_results