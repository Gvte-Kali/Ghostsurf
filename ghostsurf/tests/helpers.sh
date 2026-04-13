#!/usr/bin/env bash
# tests/helpers.sh — fonctions communes aux tests

PASS=0; FAIL=0

assert() {
    local desc=$1 result=$2 expected=$3
    if [[ "$result" == "$expected" ]]; then
        log_success "PASS: $desc → '$result'"
        ((PASS++)) || true
    else
        log_error "FAIL: $desc (attendu='$expected' obtenu='$result')"
        ((FAIL++)) || true
    fi
}

assert_not_empty() {
    local desc=$1 result=$2
    if [[ -n "$result" ]]; then
        log_success "PASS: $desc → '$result'"
        ((PASS++)) || true
    else
        log_error "FAIL: $desc (valeur vide)"
        ((FAIL++)) || true
    fi
}

assert_contains() {
    local desc=$1 result=$2 needle=$3
    if [[ "$result" == *"$needle"* ]]; then
        log_success "PASS: $desc → '$result'"
        ((PASS++)) || true
    else
        log_error "FAIL: $desc ('$needle' absent de '$result')"
        ((FAIL++)) || true
    fi
}

print_results() {
    echo ""
    echo "=== Résultats: $PASS passés, $FAIL échoués ==="
    [[ $FAIL -eq 0 ]]
}
