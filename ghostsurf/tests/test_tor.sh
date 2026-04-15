#!/usr/bin/env bash
set -e

GHOSTSURF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export STATE_DIR="/var/lib/ghostsurf"
source "$GHOSTSURF_DIR/core/logger.sh"
source "$GHOSTSURF_DIR/core/distro.sh"
source "$GHOSTSURF_DIR/core/tor.sh"
source "$GHOSTSURF_DIR/tests/helpers.sh"

echo "=== Tests tor.sh ==="

distro_detect

# ── tor_check_dns_leak hors GhostSurf ─────────────────────────────────────
# Si resolv.conf ne pointe pas vers 127.0.0.1, le leak doit être détecté
ns=$(grep -m1 -oP '^nameserver\s+\K\S+' /etc/resolv.conf 2>/dev/null || echo "?")
if [[ "$ns" != "127.0.0.1" ]]; then
    result=$(tor_check_dns_leak 2>/dev/null && echo "no-leak" || echo "leak")
    assert "DNS leak détecté hors GhostSurf" "$result" "leak"
else
    log_info "SKIP: tor_check_dns_leak hors GhostSurf (resolv.conf déjà → 127.0.0.1)"
fi

# ── tor_is_active retourne un état ────────────────────────────────────────
tor_st=$(tor_is_active 2>/dev/null && echo "actif" || echo "inactif")
assert_not_empty "tor_is_active retourne un état" "$tor_st"

# ── Tests nécessitant Tor actif ────────────────────────────────────────────
if tor_is_active 2>/dev/null; then

    # tor_myip
    myip_out=$(tor_myip 2>/dev/null)
    assert_contains "tor_myip contient 'IP Tor'" "$myip_out" "IP Tor"
    assert_contains "tor_myip contient 'IsTor'"  "$myip_out" "IsTor"
    assert_contains "tor_myip contient 'Pays'"   "$myip_out" "Pays"

    # tor_uptime
    uptime_out=$(tor_uptime 2>/dev/null)
    assert_not_empty "tor_uptime non vide" "$uptime_out"

    # tor_circuit_count
    circuits=$(tor_circuit_count 2>/dev/null)
    assert_not_empty "tor_circuit_count retourne une valeur" "$circuits"

    # tor_check_dns_leak avec GhostSurf actif — doit passer
    if tor_check_dns_leak 2>/dev/null; then
        assert "DNS leak absent avec GhostSurf actif" "ok" "ok"
    else
        assert "DNS leak absent avec GhostSurf actif" "fail" "ok"
    fi

    # tor_check_ip retourne quelque chose
    ip_out=$(tor_check_ip 2>/dev/null)
    assert_not_empty "tor_check_ip retourne une IP" "$ip_out"

else
    log_info "SKIP: tests Tor actif (service Tor inactif)"
fi

print_results
