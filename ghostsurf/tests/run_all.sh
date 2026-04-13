#!/usr/bin/env bash
GHOSTSURF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$GHOSTSURF_DIR"

TOTAL_PASS=0; TOTAL_FAIL=0

run_test() {
    local script=$1 needs_root=${2:-false}
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "► $(basename "$script")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ "$needs_root" == "true" && $EUID -ne 0 ]]; then
        echo "  [SKIP] Requiert root"
        return
    fi

    if bash "$script"; then
        ((TOTAL_PASS++)) || true
    else
        ((TOTAL_FAIL++)) || true
    fi
}

run_test tests/test_distro.sh   false
run_test tests/test_snapshot.sh true
run_test tests/test_firewall.sh true
run_test tests/test_spoof.sh    true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Suites: $TOTAL_PASS passées, $TOTAL_FAIL échouées"
[[ $FAIL -eq 0 ]]