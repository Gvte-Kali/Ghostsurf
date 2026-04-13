#!/usr/bin/env bash
set -e
[[ $EUID -eq 0 ]] || { echo "Requiert root: sudo bash tests/test_spoof.sh"; exit 1; }

GHOSTSURF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export STATE_DIR="/var/lib/ghostsurf"
source "$GHOSTSURF_DIR/core/logger.sh"
source "$GHOSTSURF_DIR/core/distro.sh"
source "$GHOSTSURF_DIR/core/snapshot.sh"
source "$GHOSTSURF_DIR/core/spoof.sh"
source "$GHOSTSURF_DIR/tests/helpers.sh"

echo "=== Tests spoof.sh ==="

distro_detect

# Fixe un hostname de référence pour le test
orig_hostname=$(hostname)
# Si on hérite d'un hostname de test précédent, on le nettoie
if [[ "$orig_hostname" == "test-ghostsurf-123" ]]; then
    orig_hostname="debian13-uni"
    hostname "$orig_hostname"
fi
orig_ts=$(sysctl -n net.ipv4.tcp_timestamps)
orig_ipv6=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
snap=$(snapshot_create)

# Test apply
spoof_apply

assert "TCP timestamps désactivés" \
    "$(sysctl -n net.ipv4.tcp_timestamps)" "0"
assert "IPv6 désactivé" \
    "$(sysctl -n net.ipv6.conf.all.disable_ipv6)" "1"
assert "hostname changé" \
    "$(test "$(hostname)" != "$orig_hostname" && echo ok)" "ok"
assert "hostname commence par localhost-" \
    "$(hostname | grep -q '^localhost-' && echo ok)" "ok"

# Test restore
spoof_restore
snapshot_restore "$snap"

assert "TCP timestamps restaurés" \
    "$(sysctl -n net.ipv4.tcp_timestamps)" "$orig_ts"
assert "IPv6 restauré" \
    "$(sysctl -n net.ipv6.conf.all.disable_ipv6)" "$orig_ipv6"
assert "hostname restauré" "$(hostname)" "$orig_hostname"

print_results