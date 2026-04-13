#!/usr/bin/env bash
# identity.sh — nouvelle identité Tor via ControlPort
# Inspiré de anonsurf (ParrotSec)

identity_new() {
    log_info "Demande d'une nouvelle identité Tor..."
    if ! tor_is_active; then
        log_error "Tor n'est pas actif"
        return 1
    fi
    # Envoie NEWNYM au ControlPort
    if command -v tor-prompt &>/dev/null; then
        echo -e 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT' | \
            nc 127.0.0.1 9051 2>/dev/null || _identity_new_curl
    else
        _identity_new_curl
    fi
    log_success "Nouvelle identité Tor demandée (attente ~10s pour le nouveau circuit)"
}

_identity_new_curl() {
    printf 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT\r\n' | \
        nc -q1 127.0.0.1 9051 2>/dev/null || true
    sleep 10
    local new_ip; new_ip=$(tor_check_ip 2>/dev/null || echo "?")
    log_info "Nouvelle IP: $new_ip"
}
