#!/usr/bin/env bash
set -e
[[ $EUID -eq 0 ]] || { echo "Requiert root: sudo bash tests/test_firewall.sh"; exit 1; }

GHOSTSURF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export STATE_DIR="/var/lib/ghostsurf"
source "$GHOSTSURF_DIR/core/logger.sh"
source "$GHOSTSURF_DIR/core/distro.sh"
source "$GHOSTSURF_DIR/core/snapshot.sh"
source "$GHOSTSURF_DIR/core/firewall.sh"
source "$GHOSTSURF_DIR/tests/helpers.sh"

echo "=== Tests firewall.sh ==="

distro_detect

# Test détection backend
backend=$(firewall_detect_backend)
assert "backend détecté" "$(test -n "$backend" && echo ok)" "ok"
log_info "Backend: $backend"

# Test dry-run
assert "dry-run nftables valide" "$(firewall_dryrun && echo ok)" "ok"

# Snapshot avant apply
snap=$(snapshot_create)

# Test apply
firewall_apply
assert "firewall actif après apply" "$(firewall_is_active && echo ok)" "ok"
assert "table ghostsurf présente" \
    "$(nft list table inet ghostsurf &>/dev/null && echo ok)" "ok"

# Test kill switch — trafic direct doit être bloqué
leak=$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null || echo "blocked")
assert "trafic clearnet direct bloqué" "$leak" "blocked"

# Test restore
firewall_restore
assert "firewall inactif après restore" \
    "$(firewall_is_active && echo ok || echo off)" "off"
assert "table ghostsurf supprimée" \
    "$(nft list table inet ghostsurf &>/dev/null && echo present || echo gone)" "gone"

# Test DNS fonctionnel après restore
snapshot_restore "$snap"
# Attente NetworkManager
sleep 3
systemctl restart NetworkManager 2>/dev/null || true
sleep 3

assert "DNS fonctionnel après restore" \
    "$(ping -c1 -W5 8.8.8.8 &>/dev/null && echo ok)" "ok"

print_results