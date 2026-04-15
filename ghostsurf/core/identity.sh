#!/usr/bin/env bash
# identity.sh — nouvelle identité Tor via ControlPort

identity_new() {
    log_info "Demande d'une nouvelle identité Tor..."
    if ! tor_is_active; then
        log_error "Tor n'est pas actif"
        return 1
    fi

    local current_ip
    current_ip=$(curl -s --max-time 5 \
        --socks5-hostname "127.0.0.1:9050" \
        https://check.torproject.org/api/ip \
        2>/dev/null | grep -oP '"IP":"\K[^"]+' || echo "")
    log_info "IP actuelle : ${current_ip:-?}"

    # Localise le cookie d'authentification Tor
    local cookie_file="/run/tor/control.authcookie"
    [[ ! -f "$cookie_file" ]] && cookie_file="/var/lib/tor/control_auth_cookie"
    [[ ! -f "$cookie_file" ]] && \
        cookie_file=$(find /run/tor /var/lib/tor -name "*.authcookie" \
                      -o -name "control_auth_cookie" 2>/dev/null | head -1 || echo "")

    _send_newnym() {
        if [[ -f "$cookie_file" ]]; then
            local cookie_hex
            cookie_hex=$(xxd -p "$cookie_file" | tr -d '\n')
            printf "AUTHENTICATE %s\r\nSIGNAL NEWNYM\r\nQUIT\r\n" "$cookie_hex" \
                | nc -q1 127.0.0.1 9051 2>/dev/null || true
        else
            printf "AUTHENTICATE \"\"\r\nSIGNAL NEWNYM\r\nQUIT\r\n" \
                | nc -q1 127.0.0.1 9051 2>/dev/null || true
        fi
        log_debug "NEWNYM envoyé"
    }

    local tries=0 new_ip=""
    while [[ $tries -lt 5 ]]; do
        _send_newnym
        log_info "Attente nouveau circuit (10s)..."
        sleep 10

        new_ip=$(curl -s --max-time 5 \
            --socks5-hostname "127.0.0.1:9050" \
            https://check.torproject.org/api/ip \
            2>/dev/null | grep -oP '"IP":"\K[^"]+' || echo "")

        if [[ -n "$new_ip" && "$new_ip" != "$current_ip" ]]; then
            log_success "Nouvelle IP : $new_ip"
            return 0
        fi
        ((tries++)) || true
        log_warn "Même IP ($new_ip), nouvelle tentative ($tries/5)..."
    done

    log_warn "IP inchangée après 5 tentatives — IP : ${new_ip:-?}"
    return 0
}
