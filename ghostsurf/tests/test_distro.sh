#!/usr/bin/env bash
set -e

GHOSTSURF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$GHOSTSURF_DIR/core/logger.sh"
source "$GHOSTSURF_DIR/core/distro.sh"
source "$GHOSTSURF_DIR/core/firewall.sh"
source "$GHOSTSURF_DIR/tests/helpers.sh"

echo "=== Tests distro.sh ==="

distro_detect

assert_not_empty "DISTRO_ID non vide" "$DISTRO_ID"
assert_not_empty "TOR_BIN non vide" "$TOR_BIN"
assert_not_empty "TOR_UID non vide" "$TOR_UID"
assert_not_empty "PKG_MANAGER non vide" "$PKG_MANAGER"
assert "TOR_BIN existe" "$(test -f "$TOR_BIN" && echo ok)" "ok"
assert "TOR_UID est numérique" "$(echo "$TOR_UID" | grep -qP '^\d+$' && echo ok)" "ok"
assert_not_empty "distro_name non vide" "$(distro_name)"
assert_not_empty "firewall backend détecté" "$(firewall_detect_backend)"

# Test check deps — requiert root pour nft
if [[ $EUID -eq 0 ]]; then
    if distro_check_deps; then
        assert "check_deps passe" "ok" "ok"
    else
        assert "check_deps passe" "fail" "ok"
    fi
else
    log_info "SKIP: check_deps (requiert root)"
fi

print_results